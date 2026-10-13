require "test_helper"

class AutomationRuleTest < ActiveSupport::TestCase
  setup do
    @ticket1 = Ticket.create!(
      subject: "Ödeme sayfası açılmıyor",
      description: "Checkout ekranında beklemede kalıyor.",
      customer_name: "Ahmet Vural",
      customer_email: "ahmet@vural.com",
      priority: "high",
      status: "new"
    )

    @ticket2 = Ticket.create!(
      subject: "Fatura talebi",
      description: "Geçen ayın faturasını PDF olarak alabilir miyiz?",
      customer_name: "Canan Dağ",
      customer_email: "canan@dag.com",
      priority: "low",
      status: "open"
    )

    @agent = User.create!(
      name: "Selin Uzman",
      email: "selin@pulsedesk.test",
      password: "password123",
      role: "agent"
    )

    @rule = AutomationRule.create!(
      name: "Yüksek Öncelikli Yeni Talepleri Eskale Et",
      trigger_type: "event",
      conditions: { "status" => "new", "priority" => "high" }.to_json,
      actions: { "set_priority" => "urgent", "add_tag" => "eskale_edildi", "assign_to_user_id" => @agent.id }.to_json,
      active: true
    )
  end

  test "Önizleme (Dry-Run) veritabanını değiştirmez" do
    old_priority = @ticket1.priority
    old_tags = @ticket1.tags
    old_assigned = @ticket1.assigned_to_id

    preview = @rule.preview

    assert_equal 2, preview[:scanned_count]
    assert_equal 1, preview[:matched_records].size
    assert_equal @ticket1.id, preview[:matched_records].first[:ticket_id]
    assert_includes preview[:matched_records].first[:planned_actions].first, "Öncelik 'URGENT' yapılacak"

    # Veritabanında hiçbir değişiklik OLMADIĞINI kesin olarak doğrula
    @ticket1.reload
    assert_equal old_priority, @ticket1.priority, "Önizleme kaydı değiştirmemelidir"
    assert_equal old_tags, @ticket1.tags
    assert_nil @ticket1.assigned_to_id
    assert_equal 0, AutomationAuditLog.count, "Önizleme denetim günlüğü üretmemelidir"
  end

  test "Gerçek çalıştırma değişiklikleri uygular ve denetim geçmişi (audit log) kaydeder" do
    result = @rule.execute!(executed_by: "Admin Test")

    assert_equal 1, result[:modified_count]
    assert_equal 0, result[:skipped_count]

    @ticket1.reload
    assert_equal "urgent", @ticket1.priority
    assert_includes @ticket1.tags, "eskale_edildi"
    assert_equal @agent.id, @ticket1.assigned_to_id

    # Denetim kaydı oluştuğunu doğrula
    assert_equal 1, AutomationAuditLog.count
    log = AutomationAuditLog.last
    assert_equal @rule.name, log.rule_name
    assert_equal "Admin Test", log.executed_by
    assert_equal 1, log.records_modified
    assert_equal "success", log.status
  end

  test "İdempotent çalışma: Aynı kural ikinci kez çalıştırıldığında mükerrer işlem yapmaz (atlanan kayıtlar)" do
    tag_rule = AutomationRule.create!(
      name: "Yeni Taleplere Etiket Ekle",
      trigger_type: "event",
      conditions: { "status" => "new" }.to_json,
      actions: { "add_tag" => "takipte" }.to_json,
      active: true
    )

    # İlk çalıştırma
    first_result = tag_rule.execute!(executed_by: "İlk Çalıştırma")
    assert_equal 1, first_result[:modified_count]
    @ticket1.reload
    assert_includes @ticket1.tags, "takipte"

    # İkinci çalıştırma (aynı kayıt üzerinde koşul hala geçerli ama etiket zaten var)
    second_result = tag_rule.execute!(executed_by: "İkinci Çalıştırma")

    assert_equal 0, second_result[:modified_count], "Mükerrer çalıştırmada kayıt değiştirilmemeli"
    assert_equal 1, second_result[:skipped_count], "Zaten uygulanmış kayıt atlanmalı"

    second_log = AutomationAuditLog.last
    assert_equal 0, second_log.records_modified
    assert_equal 1, second_log.records_skipped
  end

  test "Kural çakışması tespiti: Zıt aksiyonları olan kuralları tespit eder" do
    conflicting_rule = AutomationRule.create!(
      name: "Çakışan Kural",
      trigger_type: "event",
      conditions: { "status" => "new", "priority" => "high" }.to_json,
      actions: { "set_priority" => "low" }.to_json,
      active: true
    )

    conflicts = @rule.detect_conflicts
    assert_equal 1, conflicts.size
    assert_includes conflicts.first, "öncelik çakışması"
  end

  test "Otomasyon kuralı silinebilir" do
    assert_difference("AutomationRule.count", -1) do
      @rule.destroy!
    end
  end
end

