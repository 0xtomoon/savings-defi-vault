# Defi Vault
Aave and Balancer Vault which is built by ERC4626 standard

## Run Tests
```
npx hardhat test
```

## Verify Contract

```
npx hardhat verify --network arbitrumOne 0xfc911338Ea7Be6f6ceA258AC1f94622e3aea66D4 --constructor-args ./scripts/arguments.js
```

/*
  Balancer Fluid Vault Token:
    BPT:BFVT = 1:1
      Deposit:
        BPT minted --> BFVT minted
      
      Withdraw:
        BPT burned --> BFVT burned


  Ques: Why the same share mechanism like aaveVault is not possible here?
  Ans: Because there are two deposit tokens, and there is no one-to-one relation between deposit token &
    underlyign tokens
*/
