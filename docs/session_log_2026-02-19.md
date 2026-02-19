# セッションログ: 2026-02-19

## 概要
BoardRushプロジェクトにおけるトリック演出の強化、スコアシステムの実装、ゲームオーバー演出の追加を行った。

---

## 1. トリック不具合の調査
- **原因特定**: 「空中ランニング現象（Air-Running）」を発見
  - 空中にいる（`Floor: Enum.Material.Air`）にもかかわらず、Humanoidの状態が `Running/Landed` に変化
  - これにより `Airborne` フラグが誤って `false` にリセットされていた
- **対策案**: `FloorMaterial` が `Air` なら接地とみなさない
- **ステータス**: 原因特定のみ、修正はユーザーの指示で保留
- デバッグログをコメントアウト

## 2. 擬似スローモーション＆カメラズーム実装（Spin720）
- `TrickService` の `Spin720` に `slowMotion = true` 追加
- `duration` を `0.45` → `1.5` 秒に変更（ゆっくり回転）
- `VectorForce` で重力の85%を相殺（ふわっとした落下）
- `InputClient` でズーム演出（FOV 70 → 30）追加
- FOVリセット処理（`resetFOV`）追加

## 3. Flip360トリック（X軸回転）追加
- `TRICK_DEFS` に `Flip360`（前方宙返り）を追加
  - `angle = math.pi * 2`, `duration = 1.5`, `slowMotion = true`, `zoom = true`
- `InputClient` で `kind == "Flip360"` の場合、回転軸を `Vector3.new(1, 0, 0)` に設定

## 4. Spin720 設定変更
- ユーザーの指示でSpin720のズームオプションを削除
  - `zoom = false` に設定
  - `isZoom` フラグをサーバー→クライアント間で送信するように分離
- さらにスローモーションも削除
  - `slowMotion` 削除、`duration` を `0.45` に戻す

### 最終的なトリック構成
| トリック | 回転軸 | Duration | スローモーション | ズーム | スコア乗数 |
|---------|--------|----------|----------------|-------|-----------|
| Spin360 | Y軸 | 0.25s | なし | なし | 1 |
| Spin720 | Y軸 | 0.45s | なし | なし | 2 |
| Flip360 | X軸 | 1.5s | あり | あり | 3.5 |

## 5. トリックスコアシステム実装
- **計算式**: `基本スコア(100) × トリック乗数 × スケボー乗数`
  - スケボー装備時: 乗数1 / 未装備時: 乗数0
- **サーバー側** (`TrickService`):
  - `EquipmentConstants` を require して装備チェック
  - `TRICK_DEFS` に `scoreMultiplier` 追加
  - `PlayerAdded` で `TrickScore` 属性を初期化
  - トリック成功時にスコア計算・`SetAttribute` で保存
  - `TrickEnded` に `earnedScore` を含めて通知
- **クライアント側** (`ScoreClient.client.luau` - 新規):
  - 画面右上にスコアUI表示
  - `GetAttributeChangedSignal("TrickScore")` でリアルタイム更新
  - トリック成功時にキャラ頭上に `BillboardGui` で「+100💰!」ポップアップ
  - 💰💵の散らばりエフェクト（GUI TextLabel × 12個）

## 6. UI調整
- `SCORE` → `💰 MONEY` に変更（ゴールドカラー）
- フォントサイズ拡大（タイトル: 14→20px、値: 28→32px）
- 枠線の色を青→ゴールドに変更
- 表示できない絵文字（🪙✨）を💰💵に変更

## 7. デフォルトヘルスバー非表示
- ゲームオーバー時に表示される灰色UIの原因を特定（Robloxデフォルトヘルスバー）
- `InputClient` に `StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)` を追加

## 8. ゲームオーバー時のスコアリセット
- `triggerGameOver` で `player:SetAttribute("TrickScore", 0)` を追加
- スケボー装備時のみリセット（未装備時はスコア維持）

## 9. ゲームオーバー演出
- **赤フラッシュ**: 画面全体が赤く光ってフェードアウト（透明度0.6→1.0、1秒間）
- **カメラシェイク**: 0.7秒間の振動（強度1.0、徐々に弱まる）
- `TrickEnded` に `gameOver = true` フラグを追加してクライアントに通知

## 10. マネー減少演出
- ゲームオーバー時にUIが拡大し、数値がパラパラとランダムに減少する演出
- 30ステップ / 2秒間で0まで減少
- スコアラベルが赤色に変化し、終了後に白に戻る
- `isDrainAnimating` フラグで属性変更リスナーを一時停止
- `AnchorPoint` を `(1, 0)` に変更して画面中央方向に拡大

## 11. ScoreGui重複問題の修正
- リスポーン時にスクリプトが再実行されてUIが重複作成される問題
- 古い `ScoreGui` を `Destroy()` してから新規作成するアプローチで解決

---

## 変更ファイル一覧
| ファイル | 種類 | 変更内容 |
|---------|------|---------|
| `TrickService.server.luau` | 修正 | トリック定義、スコア計算、ゲームオーバー演出通知 |
| `InputClient.client.luau` | 修正 | X軸回転、ズーム制御、ゲームオーバー演出、ヘルスバー非表示 |
| `ScoreClient.client.luau` | **新規** | スコアUI表示、獲得演出、マネー減少演出 |
