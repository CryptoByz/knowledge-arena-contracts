# Knowledge Arena - Smart Contracts

## Kurulum

```bash
npm install
cp .env.example .env
# .env dosyasını doldur
```

## .env Doldurma

```
ADMIN_PRIVATE_KEY=0x...         # Deploy eden + günlük merkle root setter wallet
ARC_RPC_URL=https://...         # ARC testnet RPC (doc'tan al)
BASE_SEPOLIA_RPC_URL=https://sepolia.base.org
ARC_USDC_ADDRESS=0x...          # ARC testnet USDC contract adresi (doc'tan al)
METADATA_BASE_URI=http://RPI5_IP:3000/metadata
```

## Compile

```bash
npm run compile
```

## Deploy

ARC Testnet:
```bash
npm run deploy:arc
```

Base Sepolia:
```bash
npm run deploy:base
```

Deploy sonrası adresler `deployments/<chainId>.json` dosyasına kaydedilir.

## Contract Adresleri (Deploy Sonrası)

- `deployments/1227.json` → ARC Testnet
- `deployments/84532.json` → Base Sepolia

Bu dosyaları frontend ve RPi5 servisine kopyala.

## Deploy Sırası (Otomatik)

1. BadgeNFT
2. PlayerProfile
3. AchievementManager
4. RewardPool
5. DailyQuiz
6. Yetkilendirmeler (otomatik)

## Önemli Notlar

- ARC testnet chain ID doc'tan doğrulanmalı (şu an 1227 yazılı)
- ARC USDC contract adresi doc'tan alınmalı
- Her chain için ayrı deploy, aynı ADMIN_PRIVATE_KEY kullanılabilir
- Deploy sonrası RPi5 servisine de contract adreslerini ekle
