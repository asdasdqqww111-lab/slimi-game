extends Node
## مشغّل حزمة الاختبارات الآلية الشاملة مع تحميل جميع أنظمة Autoload الحقيقية للمشروع:
## يشغّل اختبارات الشخصية والفيزياء والرفيق (SlimiSystemsTestSuite + SlimiCinematicCharacterQA)
## متبوعة باختبارات إعادة تصميم الواجهة والتجربة المتكاملة (SlimiUIUXRedesignQA).


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var core_suite := SlimiSystemsTestSuite.new()
	var ok_core: bool = await core_suite.run_all(get_tree())

	var ui_suite := SlimiUIUXRedesignQA.new()
	var ok_ui: bool = await ui_suite.run_all(get_tree())

	var total_passed: int = core_suite.passed_count + ui_suite.passed_count
	var total_failed: int = core_suite.failed_count + ui_suite.failed_count
	print("\n============================================================")
	print("المجموع الكلي لجميع حزم الاختبارات: نجح %d | فشل %d" % [total_passed, total_failed])
	print("============================================================")

	get_tree().quit(0 if (ok_core and ok_ui) else 1)
