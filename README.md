This project was created while learning **Account Abstraction** from the [Cyfrin Updraft](https://updraft.cyfrin.io/) course by Patrick Collins.  
It explores the core principles of **ERC-4337**, how to build **Smart Contract Wallets**, and implement **Account Abstraction** on both Ethereum (Sepolia) and zkSync (EraVM).

---

## ✅ Transaction Success (Arbitrum)

- **Tx Hash:** [`0xed270e...`](https://sepolia.arbiscan.io/tx/0xed270e0016df0fe322e1b97cf9acb8caf861502783beb9270f874761e2c684a6)
- **Deployed Minimal Account:** `0xdCe0f65638D3860065E68393b25b5f4917773ef1`

---

## 🧾 Project Structure

```
.
├── src/                  # Smart contracts
│   ├── ethereum/         # Contracts for Ethereum & testnets (e.g. Sepolia)
│   └── zksync/           # Contracts for zkSync Era
│
├── script/               # Deployment & interaction scripts
│   ├── DeployMinimal.s.sol
│   ├── SendPackedUserOp.s.sol
│   └── HelperConfig.s.sol
│
├── test/                 # Contract tests
├── lib/                  # External dependencies
├── foundry.toml          # Foundry config
└── Makefile              # Common development commands

````

---

## ⚙️ Getting Started

### ✅ Prerequisites

- [Foundry](https://getfoundry.sh/)
- RPC URLs (Sepolia, zkSync, Arbitrum, etc.)
- Private Key(s)  
- Etherscan & Block Explorer API Keys (for verification)

---

### 📦 Installation

```bash
git clone https://github.com/ziadmag90/Foundry-Account-Abstraction.git
cd Foundry-Account-Abstraction
forge install
````

---

## 🧪 Build & Test

```bash
forge build
forge test
```

---

## 🎯 Deploy Minimal Account

> Deploys a smart contract wallet (minimal account)

```bash
forge script script/DeployMinimal.s.sol:DeployMinimal \
  --rpc-url <your_rpc_url> \
  --account <wallet-name> \
  --broadcast
```

---

## 📤 Send a Packed User Operation (ERC-4337)

> Sends a `UserOperation` manually crafted and signed

```bash
forge script script/SendPackedUserOp.s.sol:SendPackedUserOp \
  --rpc-url <your_rpc_url> \
  --account <wallet-name> \
  --broadcast
```

---

## ⚠️ Notes on zkSync Support

* zkSync Era **does not support `create`/`create2`** in raw assembly (used by many helper libraries).
* Avoid using raw `create(...)` in inline assembly — instead use the `new` keyword.
* EraVM does **not** use bytecode for deployment but rather **bytecode hashes**.
* You may encounter errors like `EXTCODECOPY not supported` or memory stack issues — these are limitations of zkSync's current compiler infrastructure.

----

## ❤ Special Thanks

To **Patrick Collins** and the [Cyfrin Updraft](https://updraft.cyfrin.io/) team for simplifying a complex topic like Account Abstraction and providing real-world examples across different chains.
