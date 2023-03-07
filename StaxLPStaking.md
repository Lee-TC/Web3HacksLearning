对传入的oldStaking地址没有进行检验，攻击者可以构造恶意合约传入，攻击合约中只需要包含migrationWithdraw函数即可，攻击者就可以获得任意数量的staking token.

```solidity
function migrateStake(address oldStaking, uint256 amount) external {
    StaxLPStaking(oldStaking).migrateWithdraw(msg.sender, amount);
    _applyStake(msg.sender, amount);
}
```
