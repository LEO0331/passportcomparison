# Passport Report Sans

The PDF exporter embeds glyphs from this static weight-400 build of Noto Sans
TC. It loads the font from the app bundle when generating a report.

The upstream source is [Noto Sans TC in Google Fonts](https://github.com/google/fonts/tree/main/ofl/notosanstc).
We used fontTools 4.60.1 to instantiate the TrueType variable font at weight
400, then renamed the font family to Passport Report Sans. The upstream
copyright and license are in [OFL-NotoSansTC.txt](OFL-NotoSansTC.txt).
