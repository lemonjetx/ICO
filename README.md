# lemonjet-ico

Fixed-price USDC sale of LJT. Foundry project targeting Base (8453) and Base Sepolia (84532).

Owner funds `LemonJetICO` with LJT, then buyers call `buy(usdcAmount)`. USDC is sent to `treasury`; LJT is transferred immediately.

`PRICE` is USDC smallest units per 1 whole LJT (`$0.10` = `100000`).

```bash
cp .env.example .env
forge build
forge test
forge script script/DeployLemonJetICO.s.sol:DeployLemonJetICO --rpc-url base_sepolia --broadcast --verify
forge script script/DeployLemonJetICO.s.sol:DeployLemonJetICO --rpc-url base --broadcast --verify
```
