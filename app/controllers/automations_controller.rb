class AutomationsController < ApplicationController
  before_action :require_agent!
  before_action :set_rule, only: [:preview, :execute, :toggle, :edit, :update, :destroy]

  def index
    @rules = AutomationRule.order(priority_order: :asc, id: :asc)
    @audit_logs = AutomationAuditLog.recent_first.limit(5)
    @conflicts = @rules.flat_map(&:detect_conflicts).uniq
  end

  def new
    @rule = AutomationRule.new(trigger_type: "event", active: true)
    @agents = User.agents
  end

  def create
    conds = {
      "status" => params[:condition_status].presence,
      "priority" => params[:condition_priority].presence,
      "unassigned" => params[:condition_unassigned].presence == "1"
    }.compact

    acts = {
      "set_priority" => params[:action_priority].presence,
      "assign_to_user_id" => params[:action_assign_to].presence,
      "add_tag" => params[:action_tag].presence
    }.compact

    @rule = AutomationRule.new(
      name: params[:rule][:name],
      description: params[:rule][:description],
      trigger_type: params[:rule][:trigger_type] || "event",
      conditions: conds.to_json,
      actions: acts.to_json,
      active: params[:rule][:active] == "1"
    )

    if @rule.save
      redirect_to preview_automation_path(@rule), notice: "Kural oluşturuldu. Güvenli önizleme (Dry-Run) sonucunu kontrol edebilirsiniz."
    else
      @agents = User.agents
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @agents = User.agents
    @conds = @rule.parsed_conditions
    @acts = @rule.parsed_actions
  end

  def update
    conds = {
      "status" => params[:condition_status].presence,
      "priority" => params[:condition_priority].presence,
      "unassigned" => params[:condition_unassigned].presence == "1"
    }.compact

    acts = {
      "set_priority" => params[:action_priority].presence,
      "assign_to_user_id" => params[:action_assign_to].presence,
      "add_tag" => params[:action_tag].presence
    }.compact

    if @rule.update(
      name: params[:rule][:name],
      description: params[:rule][:description],
      trigger_type: params[:rule][:trigger_type],
      conditions: conds.to_json,
      actions: acts.to_json,
      active: params[:rule][:active] == "1"
    )
      redirect_to preview_automation_path(@rule), notice: "Kural güncellendi. Yeni önizleme (Dry-Run) simülasyonunu inceleyebilirsiniz."
    else
      @agents = User.agents
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    rule_name = @rule.name
    @rule.destroy!
    redirect_to automations_path, notice: "'#{rule_name}' otomasyon kuralı silindi."
  end

  def preview
    @preview = @rule.preview
    @conflicts = @rule.detect_conflicts
  end

  def execute
    result = @rule.execute!(executed_by: "#{current_user.name} (#{current_user.role.capitalize})")
    
    redirect_to automations_path, notice: "Kural '#{@rule.name}' çalıştırıldı: #{result[:modified_count]} kayıt güncellendi, #{result[:skipped_count]} kayıt mükerrerlik nedeniyle atlandı."
  end

  def toggle
    @rule.update!(active: !@rule.active)
    state_text = @rule.active? ? "etkinleştirildi" : "devre dışı bırakıldı"
    redirect_to automations_path, notice: "Kural '#{@rule.name}' başarıyla #{state_text}."
  end

  def audit_logs
    @logs = AutomationAuditLog.recent_first
  end

  private

  def set_rule
    @rule = AutomationRule.find(params[:id])
  end
end
