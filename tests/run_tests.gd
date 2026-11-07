extends Node
## مشغّل حزمة الاختبارات الآلية الشاملة مع تحميل جميع أنظمة Autoload الحقيقية للمشروع.


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var suite := SlimiSystemsTestSuite.new()
	var ok: bool = await suite.run_all(get_tree())
	get_tree().quit(0 if ok else 1)
