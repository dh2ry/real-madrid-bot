--!nonstrict
-- Achievements, flashlight skins and endings.

local Progression = {}

Progression.Achievements = {
	checked_in = { name = "تسجيل الوصول", desc = "ادخل فندق غراند أوريليا.", coins = 10 },
	lights_on = { name = "ليكن نور", desc = "أعد الكهرباء إلى الفندق.", coins = 20 },
	going_up = { name = "إلى الأعلى", desc = "اركب المصعد.", coins = 10 },
	hide_seek = { name = "الغميضة", desc = "أفلت من مطاردة الظل بالاختباء.", coins = 30 },
	rescuer = { name = "لا أحد يُترك خلفنا", desc = "أنعش أحد رفاقك.", coins = 25 },
	archivist = { name = "أمين الأرشيف", desc = "اقرأ الوثائق الـ12 كلها (على مدى كل الجولات).", coins = 60 },
	escape = { name = "وقت المغادرة", desc = "اهرب من الفندق.", coins = 0 },
	liberation = { name = "ارقدي الآن يا لينا", desc = "دمّر القلب.", coins = 0 },
	concierge = { name = "موظف الشهر", desc = "خذ المفتاح الرئيسي.", coins = 0 },
	secret = { name = "خدمة الغرف", desc = "اكتشف النهاية السرية.", coins = 0 },
	insomniac = { name = "الأرِق", desc = "أنهِ جولة على صعوبة الكابوس.", coins = 100 },
	untouchable = { name = "لا يُمَس", desc = "أنهِ جولة دون أن تسقط.", coins = 75 },
}
Progression.AchievementOrder = {
	"checked_in",
	"lights_on",
	"going_up",
	"hide_seek",
	"rescuer",
	"archivist",
	"escape",
	"liberation",
	"concierge",
	"secret",
	"insomniac",
	"untouchable",
}

-- Flashlight skins: beam colour, body colour and how to unlock.
Progression.Skins = {
	classic = { name = "كلاسيكي", beam = Color3.fromRGB(255, 236, 200), body = Color3.fromRGB(40, 40, 42), unlock = nil },
	gold = { name = "ذهبي عتيق", beam = Color3.fromRGB(255, 214, 150), body = Color3.fromRGB(178, 142, 74), unlock = "lights_on" },
	coldblue = { name = "أزرق بارد", beam = Color3.fromRGB(170, 205, 255), body = Color3.fromRGB(60, 80, 110), unlock = "archivist" },
	crimson = { name = "قرمزي", beam = Color3.fromRGB(255, 150, 140), body = Color3.fromRGB(92, 24, 34), unlock = "concierge" },
	lantern = { name = "فانوس الأرِق", beam = Color3.fromRGB(255, 190, 110), body = Color3.fromRGB(52, 34, 24), unlock = "insomniac" },
	spectral = { name = "طيفي", beam = Color3.fromRGB(190, 255, 230), body = Color3.fromRGB(200, 230, 225), unlock = "secret" },
}
Progression.SkinOrder = { "classic", "gold", "coldblue", "crimson", "lantern", "spectral" }

Progression.Endings = {
	escape = {
		title = "المغادرة",
		subtitle = "النهاية 1 من 4 - الهروب",
		text = "ختمتَ المختبر وركضت. خلفك، يطوي غراند أوريليا نفسه في المطر، وأضواء ردهته ما زالت مشتعلة.\n\nغدًا لن يبقى أي سجل يقول إنه كان هنا. لكن في مكان ما يرنّ جرس، وسيأتي أحدهم دائمًا.",
	},
	liberation = {
		title = "ارقدي الآن يا لينا",
		subtitle = "النهاية 2 من 4 - التحرير",
		text = "لمست القلادة القلب، فتذكّرها القلب. ثم توقّف.\n\nوبينما تصعد نحو الفجر، يتنفّس الفندق الصعداء. تنطفئ النوافذ واحدة تلو الأخرى، ولأول مرة منذ خمسين عامًا يصبح غراند أوريليا فارغًا حقًا.",
	},
	concierge = {
		title = "موظف الشهر",
		subtitle = "النهاية 3 من 4 - الحارس الجديد",
		text = "المفتاح الرئيسي دافئ في يدك. ينحني هالدن، يخلع قفازيه، ويتلاشى أخيرًا.\n\nسيأتي الضيوف. إنهم يأتون دائمًا. وستكون أنت بانتظارهم عند المكتب، مبتسمًا، ومعك مفتاح لكل غرفة.",
	},
	secret = {
		title = "خدمة الغرف",
		subtitle = "النهاية السرية - الاستيقاظ",
		text = "وُضعت كل صفحة من القصة أمام القلب، وقرأتها الطفلة كلها.\n\nتفتح لينا عينيها. يتوقف المطر. تمتلئ الردهة بالموسيقى، والثريات ساطعة، وهو 6 مارس 1974 من جديد - لكن هذه المرة، يغادر الجميع في الصباح.",
	},
}

return Progression
