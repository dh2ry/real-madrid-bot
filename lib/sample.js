// بيانات تجريبية لمعاينة تصميم بطاقة التشكيلة فقط (ليست تشكيلة حقيقية)
export const SAMPLE_FIXTURE = {
  id: 'preview',
  kickoff: Date.now() + 3600000,
  competition: 'Primera Division',
  isHome: true,
  opponent: { name: 'Barcelona', fullName: 'FC Barcelona', crest: 'https://crests.football-data.org/81.png' },
  rmCrest: 'https://crests.football-data.org/86.png',
  venue: 'سانتياغو برنابيو',
};

export const SAMPLE_LINEUP = {
  formation: '4-2-3-1',
  coachAr: 'جوزيه مورينيو',
  opponentAr: 'برشلونة',
  competitionAr: 'الدوري الإسباني',
  lines: [
    [{ name: 'كورتوا', number: 1 }],
    [{ name: 'كاريراس', number: 18 }, { name: 'هاوسن', number: 24 }, { name: 'ميليتاو', number: 3 }, { name: 'أرنولد', number: 12 }],
    [{ name: 'تشواميني', number: 14 }, { name: 'فالفيردي', number: 8 }],
    [{ name: 'فينيسيوس', number: 7 }, { name: 'بيلينغهام', number: 5 }, { name: 'رودريغو', number: 11 }],
    [{ name: 'مبابي', number: 10 }],
  ],
  subs: [
    { name: 'لونين', number: 13 }, { name: 'روديغر', number: 22 }, { name: 'كارفاخال', number: 2 },
    { name: 'أسينسيو', number: 17 }, { name: 'كامافينغا', number: 6 }, { name: 'غولر', number: 15 },
    { name: 'ماستانتونو', number: 30 }, { name: 'إندريك', number: 16 }, { name: 'براهيم', number: 21 },
  ],
};
