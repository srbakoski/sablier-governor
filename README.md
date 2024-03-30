# 🗳️ Sablier Governor

🧪 An open-source, custom Governor contract that incorporates tokens from Sablier streams into the calculation of voting power.

⚙️ Built with Solidity, powered by Foundry.

## Requirements

Before you begin, you need to install the following tools:

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- Yarn ([v1](https://classic.yarnpkg.com/en/docs/install/) or [v2+](https://yarnpkg.com/getting-started/install))
- [Git](https://git-scm.com/downloads)

## Quickstart

To get started with Sablier Governor, follow the steps below:

1. Clone this repo & install dependencies

```
git clone git@github.com:srbakoski/sablier-governor.git
cd sablier-governor
yarn install
cd packages/hardhat
yarn install
```

2. On a second terminal, deploy the contract:

```
yarn deploy --network base/arbitrum
```

This command deploys a test smart contract to the Base/Arbitrum network. The contract is located in `packages/hardhat/contracts` and can be modified to suit your needs. The `yarn deploy` command uses the deploy script located in `packages/hardhat/deploy` to deploy the contract to the network. You can also customize the deploy script.

3. Add contracts to `externalContracts.ts`:
   Add contract data to your `packages/nextjs/contracts/externalContracts.ts` file, which would let you use Scaffold-ETH 2 hooks.

To achieve this, include the contract name, its address, and abi in `externalContracts.ts` for each chain ID. Ensure to update the `targetNetworks` in scaffold.config.ts to your preferred chains to enable hooks typescript autocompletion.

4. On a third terminal, start your NextJS app:

```
yarn start
```

Visit your app on: `http://localhost:3000`. You can interact with your smart contract using the `Debug Contracts` page. You can tweak the app config in `packages/nextjs/scaffold.config.ts`.

- Edit your smart contract `YourContract.sol` in `packages/hardhat/contracts`
- Edit your frontend in `packages/nextjs/pages`
- Edit your deployment scripts in `packages/hardhat/deploy`

5. To run tests use:

```
forge test
```

## Documentation

Visit our [docs](https://docs.scaffoldeth.io) to learn how to start building with Scaffold-ETH 2.

To know more about its features, check out our [website](https://scaffoldeth.io).

## Contributing to Scaffold-ETH 2

We welcome contributions to Scaffold-ETH 2!

Please see [CONTRIBUTING.MD](https://github.com/scaffold-eth/scaffold-eth-2/blob/main/CONTRIBUTING.md) for more information and guidelines for contributing to Scaffold-ETH 2.
