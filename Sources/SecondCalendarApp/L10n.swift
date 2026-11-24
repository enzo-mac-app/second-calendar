import Foundation
import CalendarCore

/// Interface text in the three languages. Kept in code (not .lproj) so the language can be
/// switched inside the app without a restart.
enum L10n {
    static func t(_ key: String, _ lang: AppLanguage) -> String {
        guard let row = table[key] else { return key }
        switch lang {
        case .zh: return row.0
        case .en: return row.1
        case .ja: return row.2
        }
    }

    static let table: [String: (String, String, String)] = [
        // Popover
        "today": ("今天", "Today", "今日"),
        "settings": ("设置", "Settings", "設定"),
        "quit": ("退出", "Quit", "終了"),
        "open_calendar": ("打开日历", "Open Calendar", "カレンダーを開く"),
        "no_events": ("没有日程", "No events", "予定なし"),
        "all_day": ("全天", "All day", "終日"),
        "join": ("加入", "Join", "参加"),
        "new_event": ("新建日程", "New event", "新規予定"),
        "title_placeholder": ("日程标题", "Event title", "予定のタイトル"),
        "save": ("保存", "Save", "保存"),
        "cancel": ("取消", "Cancel", "キャンセル"),
        "grant_calendar": ("允许访问日历，显示你的日程", "Allow calendar access to show your events", "カレンダーへのアクセスを許可して予定を表示"),
        "calendar_denied": ("日历权限没开，点这里去系统设置打开", "Calendar access is off. Click to open System Settings", "カレンダーへのアクセスがオフです。クリックしてシステム設定を開く"),
        "colleagues": ("同事时间", "Colleagues", "同僚の時間"),
        "working": ("上班中", "Working", "勤務中"),
        "off_hours": ("下班", "Off hours", "勤務時間外"),
        "weekend": ("周末", "Weekend", "週末"),
        "tomorrow": ("明天", "tomorrow", "明日"),
        "yesterday": ("昨天", "yesterday", "昨日"),
        "kind_off": ("放假", "Day off", "休み"),
        "kind_workday": ("补班", "Workday", "出勤日"),
        "kind_observance": ("节日", "Observance", "記念日"),
        "no_data_year": ("还没有这一年的调休数据", "No holiday data for this year yet", "この年の祝日データはまだありません"),
        "countdown_today": ("今天：%@", "Today: %@", "今日：%@"),
        "save_failed": ("没保存成功：%@", "Couldn't save: %@", "保存できませんでした：%@"),

        // Settings
        "general": ("通用", "General", "一般"),
        "calendars": ("日历", "Calendars", "カレンダー"),
        "language": ("语言", "Language", "言語"),
        "primary_region": ("主日历", "My calendar", "メインの暦"),
        "primary_hint": ("切换语言时会自动换成对应国家：中文→中国，English→美国，日本語→日本。", "Changing the language switches this too: 中文 → China, English → US, 日本語 → Japan.", "言語を切り替えると連動します：中文→中国、English→アメリカ、日本語→日本。"),
        "show_lunar": ("显示农历、节气和传统节日", "Show Chinese lunar dates and solar terms", "旧暦・二十四節気・伝統行事を表示"),
        "overlay": ("同时标出这些国家的假日（彩色小点）", "Also mark holidays in (coloured dots)", "こちらの国の祝日も表示（色の点）"),
        "week_start": ("每周第一天", "Week starts on", "週の始まり"),
        "sunday": ("周日", "Sunday", "日曜"),
        "monday": ("周一", "Monday", "月曜"),
        "menu_bar": ("菜单栏显示", "Menu bar shows", "メニューバーの表示"),
        "label_date": ("日期", "Date", "日付"),
        "label_weekday": ("星期", "Weekday", "曜日"),
        "label_lunar": ("农历", "Lunar date", "旧暦"),
        "label_time": ("时间", "Time", "時刻"),
        "launch_at_login": ("开机自动启动", "Open at login", "ログイン時に起動"),
        "reminders": ("节假日提醒：前一天晚上 8 点提醒补班和放假", "Holiday reminders: 8 pm the evening before a day off or make-up workday", "休日リマインダー：休みや出勤日の前日20時に通知"),
        "holiday_data": ("节假日数据", "Holiday data", "祝日データ"),
        "update_now": ("立即更新", "Update now", "今すぐ更新"),
        "updating": ("正在更新…", "Updating…", "更新中…"),
        "rule_based": ("按联邦假日规则计算", "computed from the federal rules", "連邦祝日の規則で計算"),
        "show_calendars": ("显示哪些日历", "Calendars to show", "表示するカレンダー"),
        "add_colleague": ("添加城市", "Add city", "都市を追加"),
        "work_hours": ("上班时间", "Work hours", "勤務時間"),
        "remove": ("删除", "Remove", "削除"),
        "colleagues_hint": ("在弹窗底部显示同事那边几点、在不在上班；当地放假会标出来（中国、美国、日本有节假日数据）。", "Shows the time where colleagues are, whether they're at work, and their public holidays (China, US and Japan).", "同僚の現地時刻と勤務中かどうかを表示し、祝日も示します（中国・アメリカ・日本）。"),
        "no_holidays_city": ("这里没有节假日数据", "No holiday data here", "祝日データなし"),
        "about": ("Second Calendar 免费自用版", "Second Calendar · free", "Second Calendar · 無料"),

        // Notifications
        "reminder_workday_title": ("明天要上班", "Working day tomorrow", "明日は出勤日"),
        "reminder_workday_body": ("调休补班（%@）", "Make-up workday (%@)", "振替出勤（%@）"),
        "reminder_holiday_title": ("明天开始放假", "Day off tomorrow", "明日から休み"),
    ]
}
