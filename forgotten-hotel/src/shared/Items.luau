--!nonstrict
-- تعريفات الأدوات. الأدوات "المهمة" (critical) تسقط مكان اللاعب إذا غادر الخادم
-- حتى لا يخسر الفريق تقدّمه أبدًا.

local Items = {
	ReceptionKey = {
		name = "مفتاح الاستقبال",
		desc = "مفتاح نحاسي ثقيل محفور عليه: «الاستقبال - للموظفين فقط».",
		icon = "🗝",
		critical = true,
	},
	Fuse = {
		name = "فيوز خزفي",
		desc = "فيوز قديم بقوة 60 أمبير. قد يعيد القاطع إلى الحياة.",
		icon = "⚡",
		critical = true,
	},
	ElevatorCard = {
		name = "بطاقة المصعد",
		desc = "بطاقة مغناطيسية ذهبية: «غراند أوريليا - مصعد الموظفين».",
		icon = "💳",
		critical = true,
	},
	Key307 = {
		name = "مفتاح الغرفة 307",
		desc = "مفتاح باهت على بطاقة مخملية. الرقم عليه مخدوش بالأظافر.",
		icon = "🗝",
		critical = true,
	},
	BasementKey = {
		name = "مفتاح القبو",
		desc = "حديد بارد. أحدهم تركه لك. أحدهم يريدك أن تنزل.",
		icon = "🗝",
		critical = true,
	},
	FuelCan = {
		name = "علبة وقود",
		desc = "نصف ممتلئة. تكفي لتشغيل المولّد.",
		icon = "⛽",
		critical = true,
	},
	Locket = {
		name = "قلادة لينا",
		desc = "قلادة فضية. في داخلها: صورة فتاة تبتسم، وخصلة شعر داكن.",
		icon = "📿",
		critical = true,
	},
	Battery = {
		name = "بطارية",
		desc = "تشحن مصباحك بالكامل. اضغط R لاستخدامها.",
		icon = "🔋",
		stack = true,
	},
	Bandage = {
		name = "ضمادة",
		desc = "تعيد بعض الصحة. اضغط H لاستخدامها.",
		icon = "✚",
		stack = true,
	},
}

Items.Order = { "ReceptionKey", "Fuse", "ElevatorCard", "Key307", "BasementKey", "FuelCan", "Locket", "Battery", "Bandage" }

return Items
