/* eslint-disable @typescript-eslint/naming-convention */
export interface Addresses {
  GELATO: string;
}

export const getAddresses = (network: string): Addresses => {
  switch (network) {
    case "hardhat":
      return {
        GELATO: "0xF82D64357D9120a760e1E4C75f646C0618eFc2F3",
      };
    case "alfajores":
      return {
        GELATO: "0xCf8EDB3333Fae73b23f689229F4De6Ac95d1f707",
      };
    case "arbitrum":
      return {
        GELATO: "0x4775aF8FEf4809fE10bf05867d2b038a4b5B2146",
      };
    case "avalanche":
      return {
        GELATO: "0x7C5c4Af1618220C090A6863175de47afb20fa9Df",
      };
    case "bnb":
      return {
        GELATO: "0x7C5c4Af1618220C090A6863175de47afb20fa9Df",
      };
    case "celo":
      return {
        GELATO: "0x8b3387eFf12D425839a7e33351e64F9fD9527262",
      };
    case "cronos":
      return {
        GELATO: "0x91f2A140cA47DdF438B9c583b7E71987525019bB",
      };
    case "evmos":
      return {
        GELATO: "0x91f2A140cA47DdF438B9c583b7E71987525019bB",
      };
    case "ethereum":
      return {
        GELATO: "0x3CACa7b48D0573D793d3b0279b5F0029180E83b6",
      };
    case "fantom":
      return {
        GELATO: "0xebA27A2301975FF5BF7864b99F55A4f7A457ED10",
      };
    case "gnosis":
      return {
        GELATO: "0x29b6603D17B9D8f021EcB8845B6FD06E1Adf89DE",
      };
    case "fuji":
      return {
        GELATO: "0xF82D64357D9120a760e1E4C75f646C0618eFc2F3",
      };
    case "goerli":
      return {
        GELATO: "0x683913B3A32ada4F8100458A3E1675425BdAa7DF",
      };
    case "arbitrumGoerli":
      return {
        GELATO: "0xF82D64357D9120a760e1E4C75f646C0618eFc2F3",
      };
    case "polygon":
      return {
        GELATO: "0x7598e84B2E114AB62CAB288CE5f7d5f6bad35BbA",
      };
    case "mumbai":
      return {
        GELATO: "0x25aD59adbe00C2d80c86d01e2E05e1294DA84823",
      };
    case "moonriver":
      return {
        GELATO: "0x91f2A140cA47DdF438B9c583b7E71987525019bB",
      };
    case "moonbeam":
      return {
        GELATO: "0x91f2A140cA47DdF438B9c583b7E71987525019bB",
      };
    case "optimisticGoerli":
      return {
        GELATO: "0xF82D64357D9120a760e1E4C75f646C0618eFc2F3",
      };
    case "optimism":
      return {
        GELATO: "0x01051113D81D7d6DA508462F2ad6d7fD96cF42Ef",
      };
    default:
      throw new Error(`No addresses for Network: ${network}`);
  }
};
