// 必要なインポートを追加
import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import * as nodemailer from "nodemailer";

// Firebase Admin SDK 初期化（もしまだ初期化していない場合）
// もし別のファイルで初期化している場合はこの行は不要
if (!admin.apps.length) {
  admin.initializeApp();
}

// SMTP接続情報（環境変数から取得するか、または直接設定）
// 実際のプロダクション環境では環境変数を使うことを推奨します
const SMTP_EMAIL =
functions.config().smtp?.email || "noreply-jam@animetourism.co.jp";
const SMTP_PASSWORD = functions.config().smtp?.password || "10172002Sota@";
const SMTP_HOST = functions.config().smtp?.host || "mail19.onamae.ne.jp";
const SMTP_PORT = parseInt(functions.config().smtp?.port || "465");

// nodemailerのトランスポーター設定
const transporter = nodemailer.createTransport({
  host: SMTP_HOST,
  port: SMTP_PORT,
  secure: SMTP_PORT === 465, // true for 465, false for other ports
  auth: {
    user: SMTP_EMAIL,
    pass: SMTP_PASSWORD,
  },
});

// sendCheckInEmail 関数
export const sendCheckInEmail = functions
  .region("asia-northeast1")
  .https.onCall(async (data: any, context: functions.https.CallableContext) => {
    // リクエストデータのロギング - デバッグのために追加
    console.log("チェックインメール送信リクエスト受信:", {
      data: data,
      auth: context.auth ?
        {
          uid: context.auth.uid,
          email: context.auth.token.email,
        } :
        "認証なし",
    });

    // 認証チェック
    if (!context.auth) {
      console.error("認証がありません");
      throw new functions.https.HttpsError(
        "unauthenticated",
        "この機能を使用するにはログインが必要です。"
      );
    }

    const userId = context.auth.uid;

    try {
      // リクエストからデータを取得
      if (!data || typeof data !== "object") {
        console.error("無効なデータ形式です", data);
        throw new functions.https.HttpsError(
          "invalid-argument",
          "無効なデータ形式です"
        );
      }

      const locationId = data.locationId;
      const checkInTitle = data.title;

      if (!locationId) {
        console.error("locationIdが指定されていません", data);
        throw new functions.https.HttpsError(
          "invalid-argument",
          "locationIdが指定されていません"
        );
      }

      console.log(
        `チェックインメール処理開始: userId=${userId}, ` +
        `locationId=${locationId}, title=${checkInTitle || "未指定"}`
      );

      // ユーザー情報を取得
      const userRecord = await admin.auth().getUser(userId);
      const userEmail = userRecord.email;

      // メールアドレスがない場合は終了
      if (!userEmail) {
        console.error(
          `ユーザー ${userId} にメールアドレスが設定されていません。`
        );
        throw new functions.https.HttpsError(
          "failed-precondition",
          "メールアドレスが設定されていません。"
        );
      }

      const userName = userRecord.displayName || "ユーザー";
      console.log(
        `ユーザー情報取得完了: email=${userEmail}, name=${userName}`
      );

      // ロケーション情報を取得
      const locationSnapshot = await admin
        .firestore()
        .collection("locations")
        .doc(locationId)
        .get();

      let locationTitle = checkInTitle || "不明なスポット";
      let imageUrl = "";
      let locationInfo = "";

      if (locationSnapshot.exists) {
        const locationData = locationSnapshot.data();
        if (locationData) {
          locationTitle = locationData.title || locationTitle;
          imageUrl = locationData.imageUrl || "";

          // 長い行を分割
          locationInfo = `
            <p>スポット名: <strong>${locationData.title || "情報なし"}</strong></p>
            ${locationData.animeName ?`<p>アニメ:
                <strong>${locationData.animeName}</strong></p>` :""}
            <p>説明: ${locationData.description || "情報なし"}</p>
          `;
        }
      }
      console.log(
        `ロケーション情報取得完了: title=${locationTitle}, ` +
        `imageUrl=${imageUrl ? "あり" : "なし"}`
      );

      // チェックイン日時のフォーマット
      const checkInDate = new Date();
      const formattedDate = checkInDate.toLocaleString("ja-JP");

      // メールテンプレートの作成
      const htmlTemplate = `
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <title>チェックイン完了</title>
        <style>
          body {
            font-family: 'Helvetica Neue', Arial, sans-serif;
            line-height: 1.6;
            color: #333;
            max-width: 600px;
            margin: 0 auto;
            padding: 20px;
          }
          .header {
            background-color: #00008b;
            color: white;
            padding: 20px;
            text-align: center;
            border-radius: 5px 5px 0 0;
          }
          .content {
            padding: 20px;
            background-color: #f9f9f9;
            border-left: 1px solid #eee;
            border-right: 1px solid #eee;
          }
          .location-info {
            background-color: white;
            border: 1px solid #eee;
            padding: 15px;
            border-radius: 5px;
            margin: 20px 0;
          }
          .footer {
            font-size: 12px;
            text-align: center;
            padding: 10px 20px;
            background-color: #f1f1f1;
            color: #666;
            border-radius: 0 0 5px 5px;
          }
          .image-container {
            text-align: center;
            margin: 15px 0;
          }
          .image-container img {
            max-width: 100%;
            border-radius: 5px;
            border: 1px solid #eee;
          }
          .user-id {
            font-size: 14px;
            color: #666;
            margin-top: 8px;
          }
        </style>
      </head>
      <body>
        <div class="header">
          <h1>チェックイン完了！</h1>
        </div>
        <div class="content">
          <p>${userName} 様</p>
          <p><strong>${locationTitle}</strong> へのチェックインが完了しました。</p>

          ${imageUrl ?
    `<div class="image-container">
            <img src="${imageUrl}"
            alt="${locationTitle}" style="max-width: 300px;">
            <div class="user-id">ユーザーID: $(userId)}</div>
          </div>
          ` :
    ""}

          <div class="location-info">
            ${locationInfo}
            <p>チェックイン日時: ${formattedDate}</p>
          </div>

          <p>今回のチェックインでポイントを獲得しました！</p>
          <p>引き続き聖地巡礼をお楽しみください。</p>
        </div>
        <div class="footer">
          <p>※このメールは自動送信されています。ご返信いただけません。</p>
          <p>※ご連絡は
          <a href="https://animetourism.co.jp/contact.html" target="_blank">こちら</a>
          からお願いいたします。</p>
          <p>&copy; 2024-2025 AnimTourism Inc. All Rights Reserved.</p>
        </div>
      </body>
      </html>
      `;

      // プレーンテキスト版も作成
      const textTemplate = `
チェックイン完了のお知らせ

${userName} 様

${locationTitle} へのチェックインが完了しました。

■ スポット情報 ■
${locationSnapshot.exists && locationSnapshot.data() ?
    locationSnapshot.data()?.title || "" :
    ""}
${locationSnapshot.exists &&
          locationSnapshot.data() &&
          locationSnapshot.data()?.animeName ?
    "アニメ: " + locationSnapshot.data()?.animeName :
    ""}
チェックイン日時: ${formattedDate}

引き続き聖地巡礼をお楽しみください。

※このメールは自動送信されています。返信はいただけません。
      `;

      // メール送信
      const mailOptions = {
        from: `"JapanAnimeMaps" <${SMTP_EMAIL}>`,
        to: userEmail,
        subject: `【チェックイン完了】${locationTitle}`,
        text: textTemplate,
        html: htmlTemplate,
      };

      console.log(
        `メール送信準備完了: to=${userEmail}, ` +
        `subject=【チェックイン完了】${locationTitle}`
      );

      // SMTPサーバーを使用してメール送信
      await transporter.sendMail(mailOptions);

      console.log(`ユーザー ${userId} にチェックイン完了メールを送信しました。`);

      // ログ記録
      await admin.firestore().collection("email_logs").add({
        type: "check_in_email",
        userId: userId,
        locationId: locationId,
        locationTitle: locationTitle,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        success: true,
      });

      return {
        success: true,
        message: "チェックイン完了メールを送信しました。",
      };
    } catch (error) {
      console.error("メール送信エラー:", error);

      // エラーログを記録
      await admin.firestore().collection("error_logs").add({
        type: "email_send_failure",
        userId: userId,
        error: (error as Error).message,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        stack: (error as Error).stack, // スタックトレースも記録
      });

      throw new functions.https.HttpsError(
        "internal",
        "メール送信に失敗しました: " + (error as Error).message
      );
    }
  });
