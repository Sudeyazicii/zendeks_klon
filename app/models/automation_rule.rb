class AutomationRule < ApplicationRecord
  TRIGGER_TYPES = %w[event time_based].freeze

  has_many :automation_audit_logs, dependent: :nullify

  validates :name, presence: true
  validates :trigger_type, inclusion: { in: TRIGGER_TYPES }

  scope :active, -> { where(active: true).order(priority_order: :asc, id: :asc) }

  # JSON hash serializers for conditions and actions
  def parsed_conditions
    return {} if conditions.blank?
    conditions.is_a?(Hash) ? conditions : JSON.parse(conditions)
  rescue JSON::ParserError
    {}
  end

  def parsed_actions
    return {} if actions.blank?
    actions.is_a?(Hash) ? actions : JSON.parse(actions)
  rescue JSON::ParserError
    {}
  end

  # Dry-run: Evaluates rules against tickets without changing any database records
  def preview
    scanned_scope = Ticket.all
    scanned_count = scanned_scope.count
    matched = []
    skipped = []

    conds = parsed_conditions
    acts = parsed_actions

    scanned_scope.find_each do |ticket|
      reasons = []
      matches = true

      # Check status condition
      if conds["status"].present?
        if conds["status"] == "breached"
          if ticket.breached?
            reasons << "SLA süresi aşılmış"
          else
            matches = false
          end
        elsif ticket.status == conds["status"]
          reasons << "Durum '#{conds['status']}' ile eşleşiyor"
        else
          matches = false
        end
      end

      # Check priority condition
      if conds["priority"].present? && matches
        if ticket.priority == conds["priority"]
          reasons << "Öncelik '#{conds['priority']}' ile eşleşiyor"
        else
          matches = false
        end
      end

      # Check unassigned condition
      if conds["unassigned"].present? && matches
        if conds["unassigned"] == true || conds["unassigned"] == "true"
          if ticket.assigned_to_id.nil?
            reasons << "Henüz bir temsilciye atanmamış"
          else
            matches = false
          end
        end
      end

      # Check older_than_hours condition
      if conds["older_than_hours"].present? && matches
        threshold = conds["older_than_hours"].to_i.hours.ago
        if ticket.created_at <= threshold
          reasons << "Kayıt #{conds['older_than_hours']} saatten daha eski (#{ticket.created_at.strftime('%d.%m %H:%M')})"
        else
          matches = false
        end
      end

      next unless matches

      # Plan actions and check if already applied (idempotency check)
      planned_actions = []
      already_applied = true

      if acts["set_priority"].present?
        planned_actions << "Öncelik '#{acts['set_priority'].upcase}' yapılacak"
        already_applied = false if ticket.priority != acts["set_priority"]
      end

      if acts["assign_to_user_id"].present?
        target_user = User.find_by(id: acts["assign_to_user_id"])
        target_name = target_user ? target_user.name : "Kullanıcı ##{acts['assign_to_user_id']}"
        planned_actions << "Atanacak çalışan: #{target_name}"
        already_applied = false if ticket.assigned_to_id != acts["assign_to_user_id"].to_i
      end

      if acts["add_tag"].present?
        tag_to_add = acts["add_tag"].to_s.strip
        planned_actions << "Etiket eklenecek: '#{tag_to_add}'"
        current_tags = ticket.tags.to_s.split(",").map(&:strip)
        already_applied = false unless current_tags.include?(tag_to_add)
      end

      if already_applied
        skipped << {
          ticket_id: ticket.id,
          ticket_number: ticket.ticket_number,
          subject: ticket.subject,
          reason: "İstenen aksiyonlar bu kayıtta zaten uygulanmış (Mükerrer işlem engellendi)."
        }
      else
        matched << {
          ticket_id: ticket.id,
          ticket_number: ticket.ticket_number,
          subject: ticket.subject,
          match_reason: reasons.join(", "),
          planned_actions: planned_actions
        }
      end
    end

    {
      rule_id: id,
      rule_name: name,
      scanned_count: scanned_count,
      matched_records: matched,
      skipped_records: skipped
    }
  end

  # Gerçek çalıştırma: DB transaction içinde uygular ve audit log kaydeder
  def execute!(executed_by: "Sistem")
    prev = preview
    modified_records = []
    error_records = []

    acts = parsed_actions

    transaction do
      prev[:matched_records].each do |item|
        ticket = Ticket.find_by(id: item[:ticket_id])
        next unless ticket

        # Re-check idempotency and safety before saving
        changes_made = []

        if acts["set_priority"].present? && ticket.priority != acts["set_priority"]
          ticket.priority = acts["set_priority"]
          changes_made << "Öncelik -> #{acts['set_priority']}"
        end

        if acts["assign_to_user_id"].present? && ticket.assigned_to_id != acts["assign_to_user_id"].to_i
          ticket.assigned_to_id = acts["assign_to_user_id"].to_i
          user = User.find_by(id: acts["assign_to_user_id"])
          changes_made << "Atandı -> #{user&.name || acts['assign_to_user_id']}"
        end

        if acts["add_tag"].present?
          tag = acts["add_tag"].to_s.strip
          existing = ticket.tags.to_s.split(",").map(&:strip).reject(&:blank?)
          unless existing.include?(tag)
            existing << tag
            ticket.tags = existing.join(", ")
            changes_made << "Etiket eklendi -> #{tag}"
          end
        end

        if ticket.save
          modified_records << {
            ticket_id: ticket.id,
            ticket_number: ticket.ticket_number,
            changes: changes_made
          }
        else
          error_records << {
            ticket_id: ticket.id,
            ticket_number: ticket.ticket_number,
            error: ticket.errors.full_messages.join(", ")
          }
        end
      end

      update_column(:last_run_at, Time.current)

      # Create audit log
      log_status = error_records.any? ? (modified_records.any? ? "partial" : "failed") : "success"
      automation_audit_logs.create!(
        rule_name: name,
        trigger_type: trigger_type,
        executed_by: executed_by,
        records_scanned: prev[:scanned_count],
        records_modified: modified_records.size,
        records_skipped: prev[:skipped_records].size,
        status: log_status,
        summary: "#{modified_records.size} kayıt güncellendi, #{prev[:skipped_records].size} kayıt mükerrerlik/zaten uygulanmış olduğu için atlandı.",
        details: {
          modified: modified_records,
          skipped: prev[:skipped_records],
          errors: error_records
        }.to_json
      )
    end

    {
      scanned_count: prev[:scanned_count],
      modified_count: modified_records.size,
      skipped_count: prev[:skipped_records].size,
      errors: error_records
    }
  end

  # Kural çakışması tespiti: Diğer aktif kurallarla zıt eylemler var mı?
  def detect_conflicts
    conflicts = []
    AutomationRule.active.where.not(id: id).each do |other|
      other_conds = other.parsed_conditions
      my_conds = parsed_conditions

      # Eğer koşullar aynı durumu veya önceliği hedefliyorsa
      common_target = (my_conds["status"].present? && my_conds["status"] == other_conds["status"]) ||
                      (my_conds["priority"].present? && my_conds["priority"] == other_conds["priority"])

      if common_target
        my_acts = parsed_actions
        other_acts = other.parsed_actions
        if my_acts["set_priority"].present? && other_acts["set_priority"].present? && my_acts["set_priority"] != other_acts["set_priority"]
          conflicts << "'#{other.name}' kuralı ile öncelik çakışması: Biri '#{my_acts['set_priority']}', diğeri '#{other_acts['set_priority']}' atıyor."
        end
      end
    end
    conflicts
  end
end
