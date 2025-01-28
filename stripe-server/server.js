require('dotenv').config();
const express = require('express');
const cors = require('cors');
const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);
const bodyParser = require('body-parser');

const app = express();

// 本番環境用のCORS設定
app.use(cors({
  origin: true, // モバイルアプリからのリクエストを許可
  methods: ['GET', 'POST'],
  allowedHeaders: ['Content-Type', 'Authorization', 'x-api-key'], // x-api-keyを追加
  credentials: true
}));

// セキュリティヘッダーの追加
app.use((req, res, next) => {
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('X-Frame-Options', 'DENY');
  res.setHeader('X-XSS-Protection', '1; mode=block');
  res.setHeader('Strict-Transport-Security', 'max-age=31536000; includeSubDomains');
  next();
});

// リクエストサイズの制限
app.use(bodyParser.json({ limit: '10kb' }));

// レート制限の実装
const rateLimit = require('express-rate-limit');
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15分
  max: 100 // IPあたりの最大リクエスト数
});
app.use(limiter);

// APIキー検証ミドルウェア
app.use((req, res, next) => {
  const apiKey = req.headers['x-api-key'];
  if (!apiKey || apiKey !== process.env.API_KEY) {
    return res.status(401).json({ error: '不正なアクセスです' });
  }
  next();
});

// リクエストログ（本番環境用）
app.use((req, res, next) => {
  const timestamp = new Date().toISOString();
  const method = req.method;
  const url = req.url;
  const ip = req.ip;

  console.log(`[${timestamp}] ${method} ${url} - IP: ${ip}`);
  if (req.body && Object.keys(req.body).length > 0) {
    console.log('Request Body:', JSON.stringify(req.body, null, 2));
  }
  next();
});

// Apple Pay用のPaymentSheet作成
app.post('/create-payment-sheet', async (req, res) => {
  try {
    const { amount, currency = 'jpy' } = req.body;

    // 入力値の検証
    if (!amount || typeof amount !== 'number' || amount <= 0) {
      return res.status(400).json({
        error: { message: '無効な金額が指定されました' }
      });
    }

    const paymentIntent = await stripe.paymentIntents.create({
      amount,
      currency,
      payment_method_types: ['card', 'apple_pay'],
      payment_method_options: {
        card: {
          request_three_d_secure: 'automatic'
        }
      }
    });

    const ephemeralKey = await stripe.ephemeralKeys.create(
      {customer: 'cus_default'},
      {apiVersion: '2023-10-16'}
    );

    const responseData = {
      paymentIntent: paymentIntent.client_secret,
      ephemeralKey: ephemeralKey.secret,
      customer: 'cus_default',
      publishableKey: process.env.STRIPE_PUBLISHABLE_KEY
    };

    console.log('PaymentSheet作成成功:', {
      ...responseData,
      paymentIntent: '***hidden***',
      ephemeralKey: '***hidden***'
    });

    res.json(responseData);
  } catch (error) {
    console.error('[ERROR] PaymentSheet作成エラー:', error);
    res.status(500).json({
      error: {
        message: 'PaymentSheet作成中にエラーが発生しました'
      }
    });
  }
});

// 通常のPaymentIntent作成
app.post('/create-payment-intent', async (req, res) => {
  try {
    const { amount, currency = 'jpy' } = req.body;

    // 入力値の検証
    if (!amount || typeof amount !== 'number' || amount <= 0) {
      return res.status(400).json({
        error: { message: '無効な金額が指定されました' }
      });
    }

    const paymentIntent = await stripe.paymentIntents.create({
      amount,
      currency,
      payment_method_types: ['card'],
      payment_method_options: {
        card: {
          request_three_d_secure: 'automatic'
        }
      }
    });

    console.log('PaymentIntent作成成功:', paymentIntent.id);

    res.json({
      clientSecret: paymentIntent.client_secret,
      id: paymentIntent.id
    });
  } catch (error) {
    console.error('[ERROR] PaymentIntent作成エラー:', error);
    res.status(500).json({
      error: {
        message: '決済の処理中にエラーが発生しました'
      }
    });
  }
});

// ヘルスチェック
app.get('/health', (req, res) => {
  // APIキー検証をスキップ
  res.json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    environment: process.env.NODE_ENV
  });
});

const PORT = parseInt(process.env.PORT || "8080");
const HOST = '0.0.0.0';

const server = app.listen(PORT, HOST, () => {
  console.log(`Server is running on http://${HOST}:${PORT}`);
  console.log('環境変数:');
  console.log('- STRIPE_SECRET_KEY:', process.env.STRIPE_SECRET_KEY ? '設定済み' : '未設定');
  console.log('- STRIPE_PUBLISHABLE_KEY:', process.env.STRIPE_PUBLISHABLE_KEY ? '設定済み' : '未設定');
  console.log('- API_KEY:', process.env.API_KEY ? '設定済み' : '未設定');
  console.log('- PORT:', PORT);
}).on('error', (err) => {
  console.error('Server error:', err);
  process.exit(1);
});

// グレースフルシャットダウンの処理を追加
process.on('SIGTERM', () => {
  console.log('SIGTERM received, shutting down...');
  server.close(() => {
    console.log('Server closed');
    process.exit(0);
  });
});

// エラーハンドリング
process.on('uncaughtException', (error) => {
  console.error('Uncaught Exception:', error);
});

process.on('unhandledRejection', (error) => {
  console.error('Unhandled Rejection:', error);
});
