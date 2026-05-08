# Passport Index Toolbox - 系統設計審查

## 1. 範圍與目標
- 建立前端為主的護照比較工具（以 Flutter Web 為優先，同時保留跨平台能力）。
- 支援 1-5 本護照比較、年份切換、以及目的地准入明細矩陣。
- 當 API 不穩定或失敗時，可自動回退到本地資料集（`lib/data.json`）。
- 以靜態部署為原則（GitHub Pages），不依賴自建後端。

## 2. 架構總覽
### 主要元件
- `lib/main.dart`：UI 組裝與應用層狀態協調。
- `lib/services/api_service.dart`：網路呼叫、快取、與 fallback 邏輯。
- `lib/models/country.dart`：國家摘要與年度資料模型。
- `lib/widgets/*`：視覺元件（輸入列、比較表、指標等）。
- `SharedPreferences`：儲存 favorites 與國家資料快取。
- `lib/data.json`：離線 fallback 資料來源。

### 執行時資料流
1. 使用者按 `Start` -> 呼叫 `ApiService.fetchCountries()`。
2. 服務先嘗試 `GET /countries`（含 timeout）。
3. API 失敗或資料無效時：
- 先讀 `SharedPreferences` 的 `cached_countries`；
- 仍不可用則載入 `lib/data.json`。
4. 使用者按 `Details` -> 對每個已選護照 lazy-load `GET /visa-single/{code}`。
5. 若細節 API 失敗，改由本地 `data.json` 提取等價的簽證代碼集合。
6. UI 使用 `visaFreeMap` 渲染矩陣，提供搜尋與「只看差異」。

## 3. 架構取捨（Tradeoff）
### 目前選擇
- 以單一 `StatefulWidget`（`_PassportComparePageState`）集中協調畫面與狀態。
- 把 fallback + 快取策略集中在 `ApiService`。
- 使用 `SharedPreferences` 儲存 JSON 字串，降低持久化複雜度。

### 優點
- 開發速度快，維運成本低。
- 無需後端服務即可完成主要功能。
- API 不穩時仍可維持可用性（多層 fallback）。

### 代價
- `main.dart` 體積偏大，UI 與流程邏輯耦合高。
- 動態 JSON 結構型別安全較弱。
- `SharedPreferences` 的 JSON blob 在資料結構演進時較脆弱。

## 4. 資料結構：為何這樣選
### 4.1 `List<String?> selectedCountryCodes`（固定長度 5）
- 為何選用：
- UI 第 N 格直接對應第 N 筆選擇，索引語意清楚。
- 比較按鈕啟用條件可直接以 `contains(null)` 判斷。
- 目標上限小（<=5），資料結構簡單且足夠。
- 替代方案：
- `Map<int, String>`：索引更明確，但空值/缺值判斷更分散。
- `List<PassportSelection>`：可讀性較好，但初期程式碼量增加。

### 4.2 `List<String> selectedYears`（與國家清單平行）
- 為何選用：
- 與國家索引對齊，O(1) 取得該欄位年份。
- 摘要卡片渲染邏輯直接、成本低。
- 替代方案：
- 合併為 `List<PassportSelection{code, year}>`，避免平行陣列風險。

### 4.3 `Map<String, Set<String>> visaFreeMap`
- 為何選用：
- Key 為護照代碼，Value 為可准入目的地代碼集合。
- `Set<String>` 查詢 membership 為 O(1)，非常適合矩陣與差異比較。
- 集合天然去重，避免重複代碼。
- 替代方案：
- `Map<String, List<String>>`：查詢變 O(n)，在大量 cell 判斷時較慢。
- Bitset/壓縮索引：規模很大時更省記憶體，但目前屬過度設計。

### 4.4 `List<Map<String, dynamic>> _favorites`
- 為何選用：
- 可直接 JSON encode/decode 存到 `SharedPreferences`。
- 快速交付功能，維持低依賴。
- 替代方案：
- `List<FavoriteSnapshot>` + serializer：型別更安全，後續演進更穩定。
- SQLite/Isar/Hive：查詢/版本治理更好，但引入維運與依賴成本。

### 4.5 `Country.yearlyData` 使用 `Map<String, dynamic>?`
- 為何選用：
- API 年份鍵是動態字串（如 `"2024"`），Map 可以自然對齊資料形狀。
- 可容忍部分年份缺漏。
- 替代方案：
- `Map<int, YearStat>`：更強型別與可維護性。
- 正規化年度資料表：適合分析場景，但開發成本更高。

## 5. 穩定性策略
- 外部 API 設定 timeout（12 秒）。
- `/countries` 採三級回退：API -> 本地快取 -> 內建資料集。
- `/visa-single/{code}` 失敗時由 `data.json` 補齊。
- 以記憶體 `_cache` 避免同護照重複請求。

## 6. 深入面試常見問題（含答題方向）
1. 為何不做後端中介層？
- 目標是靜態部署與低維運，資料是 read-heavy，直接串接 API 成本最低。

2. 為何不一開始就用 Riverpod/BLoC？
- 目前是單畫面且狀態範圍可控，先以 local state 換取交付速度。
- 若功能擴大，再進行 feature-level state 拆分。

3. 為何 visa 資料用 `Set`？
- 比較表與差異模式大量做 membership check，`Set` 在時間複雜度上最合理。

4. 現階段最大風險是什麼？
- `main.dart` 集中度過高（可擴充性風險）以及 favorites 動態結構（型別風險）。

5. 第一個重構點會放哪裡？
- 抽出 `ComparisonController`（或同等協調層），並把 favorites 改為 typed model。
- 維持 `ApiService` fallback 契約不變，避免行為回歸。

6. 若資料規模變大怎麼做？
- 先正規化資料結構、加強型別模型、將重運算移到 isolate，必要時加入伺服器端分頁/篩選。

## 7. 建議下一步
- 拆分狀態為 `selection`、`comparison`、`favorites` 三個 feature controller。
- favorites 改為 typed DTO + 版本欄位（支援未來 schema migration）。
- 補強 fallback 順序與壞資料案例的契約測試。
