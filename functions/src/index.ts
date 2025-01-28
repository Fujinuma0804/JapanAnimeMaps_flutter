import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import Stripe from "stripe";

admin.initializeApp();

const stripe = new Stripe(functions.config().stripe.secret_key, {
  apiVersion: "2023-10-16",
});

export const createPaymentIntent = functions
  .region("asia-northeast1")
  .https.onCall(async (data, context) => {
    // デバッグログ: 関数開始
    console.log("createPaymentIntent function started", {
      userId: context.auth?.uid,
      orderId: data.orderId,
    });

    // 認証確認
    if (!context.auth) {
      console.error("Authentication error: No user context");
      throw new functions.https.HttpsError(
        "unauthenticated",
        "ユーザー認証が必要です。"
      );
    }

    try {
      // 注文情報の取得
      console.log("Fetching order data...");
      const orderRef = await admin
        .firestore()
        .collection("orders")
        .doc(data.orderId)
        .get();

      const orderData = orderRef.data();
      if (!orderData) {
        console.error("Order not found", {orderId: data.orderId});
        throw new functions.https.HttpsError(
          "not-found",
          "注文情報が見つかりません。"
        );
      }

      // カート内の商品情報を取得
      console.log("Fetching cart items...");
      const cartSnapshot = await admin
        .firestore()
        .collection("users")
        .doc(context.auth.uid)
        .collection("shopping_cart")
        .get();

      // 合計金額の計算（小計）
      let subtotal = 0;
      const cartItems = cartSnapshot.docs.map((doc) => {
        const item = doc.data();
        const itemTotal = item.price * item.quantity;
        subtotal += itemTotal;
        return {
          id: doc.id,
          price: item.price,
          quantity: item.quantity,
          total: itemTotal,
        };
      });

      // デバッグログ: カート内容と小計
      console.log("Cart summary:", {
        items: cartItems,
        subtotal: subtotal,
      });

      // PaymentIntentの作成
      console.log("Creating PaymentIntent...");
      const paymentIntent = await stripe.paymentIntents.create({
        amount: subtotal, // 税抜き金額（小計）で決済
        currency: "jpy",
        customer: data.customerId,
        metadata: {
          orderId: data.orderId,
          userId: context.auth.uid,
          subtotal: subtotal.toString(),
        },
        automatic_payment_methods: {
          enabled: true,
        },
      });

      // デバッグログ: PaymentIntent作成結果
      console.log("PaymentIntent created", {
        paymentIntentId: paymentIntent.id,
        amount: paymentIntent.amount,
        status: paymentIntent.status,
      });

      // 注文情報の更新
      console.log("Updating order information...");
      await orderRef.ref.update({
        paymentIntentId: paymentIntent.id,
        subtotal: subtotal,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        paymentStatus: paymentIntent.status,
      });

      console.log("Payment process completed successfully");
      return {
        clientSecret: paymentIntent.client_secret,
        amount: subtotal,
        paymentIntentId: paymentIntent.id,
      };
    } catch (error) {
      console.error("Payment Intent creation error:", error);
      throw new functions.https.HttpsError(
        "internal",
        "Payment Intent の作成に失敗しました。"
      );
    }
  });

// 決済状況の監視用関数
export const onPaymentStatusUpdate = functions
  .region("asia-northeast1")
  .https.onRequest(async (request, response) => {
    console.log("Received webhook event:", request.body.type);

    const sig = request.headers["stripe-signature"];
    let event;

    try {
      event = stripe.webhooks.constructEvent(
        request.rawBody,
        sig,
        functions.config().stripe.webhook_secret
      );
    } catch (err) {
      console.error("Webhook signature verification failed", err);
      response.status(400).send("Webhook Error");
      return;
    }

    if (event.type === "payment_intent.succeeded") {
      const paymentIntent = event.data.object;
      console.log("PaymentIntent succeeded:", {
        id: paymentIntent.id,
        orderId: paymentIntent.metadata.orderId,
      });

      // 注文ステータスの更新
      const orderId = paymentIntent.metadata.orderId;
      if (orderId) {
        try {
          await admin
            .firestore()
            .collection("orders")
            .doc(orderId)
            .update({
              paymentStatus: "succeeded",
              paidAt: admin.firestore.FieldValue.serverTimestamp(),
            });
          console.log("Order status updated to succeeded", {orderId});
        } catch (error) {
          console.error("Error updating order status", error);
        }
      }
    }

    response.json({received: true});
  });
