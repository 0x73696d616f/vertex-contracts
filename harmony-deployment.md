# Harmony Deployment guide

## Command Line Interface (CLI)

### Prerequisites

1. Configure the `.env` file:

```
PROVIDER_URL_MAINNET=https://api.harmony.one
NETWORK=mainnet
PRIVATE_KEY=
PRIVATE_KEY_1=
PRIVATE_KEY_2=
PRIVATE_KEY_3=
HARDHAT_PRIVATE_KEY=
RPC_URL=https://api.s0.t.hmny.io/
OWNER_ADDRESS=
```

2. Install Dependencies:

```
yarn install
```

3. Compile the contracts:

```
yarn compile
```

### Profitable Trades Script

Execute 3 trades, 2 long and 1 short. The first long to close a position, being profitable and the short to as well.

#### Example

```
make trade
```
