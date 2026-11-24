# Third-party code and data

Second Calendar uses the following. Thank you to their authors.

| What | Used for | License |
|---|---|---|
| [6tail/lunar-swift](https://github.com/6tail/lunar-swift) | Chinese lunar dates, solar terms, traditional festivals | MIT, © 2023 6tail |
| [Sparkle](https://github.com/sparkle-project/Sparkle) | Automatic updates | MIT, © Andy Matuschak, Elgato Systems, Kornel Lesiński and contributors |
| [NateScarlet/holiday-cn](https://github.com/NateScarlet/holiday-cn) | China's public holidays and make-up workdays (调休), from State Council notices | MIT, © NateScarlet |
| [国民の祝日 CSV](https://www8.cao.go.jp/chosei/shukujitsu/gaiyou.html), Cabinet Office of Japan | Japan's national holidays, including substitute holidays | Public Data License (政府標準利用規約 第2.0版, compatible with CC BY 4.0). 出典：内閣府ホームページ |

US federal holidays are computed in code from 5 U.S.C. 6103 and need no data.

Holiday data bundled in `Sources/CalendarCore/BundledHolidays.swift` and `Data/raw/` comes from the two
sources above; the app downloads newer copies of the same files at runtime.
