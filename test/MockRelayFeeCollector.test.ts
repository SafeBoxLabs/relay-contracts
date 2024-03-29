import hre = require("hardhat");
const { ethers } = hre;
import { expect } from "chai";
import {
  IGelato,
  GelatoRelay,
  MockGelatoRelayFeeCollector,
  MockERC20,
} from "../typechain";
import {
  MessageFeeCollectorStruct,
  ExecWithSigsFeeCollectorStruct,
} from "../typechain/contracts/interfaces/IGelato";

import { utils, Signer } from "ethers";
import { getAddresses } from "../src/addresses";
import { generateDigestFeeCollector } from "../src/utils/EIP712Signatures";
import {
  setBalance,
  impersonateAccount,
} from "@nomicfoundation/hardhat-network-helpers";

const EXEC_SIGNER_PK =
  "0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d";
const CHECKER_SIGNER_PK =
  "0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a";
const FEE_COLLECTOR = "0x3AC05161b76a35c1c28dC99Aa01BEd7B24cEA3bf";
const correlationId = utils.formatBytes32String("CORRELATION_ID");
const FUJI_DIAMOND_OWNER = "0x9386CdCcbf11335587F2C769BB88E6e30685945e";

describe("Test MockGelatoRelayFeeCollector Smart Contract", function () {
  let executorSigner: Signer;
  let checkerSigner: Signer;
  let executorSignerAddress: string;
  let checkerSignerAddress: string;

  let gelatoRelay: GelatoRelay;
  let mockRelayFeeCollector: MockGelatoRelayFeeCollector;
  let mockERC20: MockERC20;

  let gelatoDiamond: IGelato;
  let targetAddress: string;
  let salt: number;
  let deadline: number;
  let feeToken: string;

  beforeEach("tests", async function () {
    if (hre.network.name !== "hardhat") {
      console.error("Test Suite is meant to be run on hardhat only");
      process.exit(1);
    }

    await hre.deployments.fixture();

    [, executorSigner, checkerSigner] = await hre.ethers.getSigners();
    executorSignerAddress = await executorSigner.getAddress();
    checkerSignerAddress = await checkerSigner.getAddress();

    gelatoRelay = (await hre.ethers.getContract("GelatoRelay")) as GelatoRelay;
    mockRelayFeeCollector = (await hre.ethers.getContract(
      "MockGelatoRelayFeeCollector"
    )) as MockGelatoRelayFeeCollector;
    mockERC20 = (await hre.ethers.getContract("MockERC20")) as MockERC20;

    targetAddress = mockRelayFeeCollector.address;
    salt = 42069;
    deadline = 2664381086;
    feeToken = mockERC20.address;

    gelatoDiamond = (await ethers.getContractAt(
      "IGelato",
      getAddresses("fuji").GELATO
    )) as IGelato;

    await impersonateAccount(FUJI_DIAMOND_OWNER); // Diamond Owner
    await setBalance(FUJI_DIAMOND_OWNER, ethers.utils.parseEther("1"));

    const fujiDiamondOwner = await ethers.getSigner(FUJI_DIAMOND_OWNER);
    await gelatoDiamond
      .connect(fujiDiamondOwner)
      .addExecutorSigners([executorSignerAddress]);
    await gelatoDiamond
      .connect(fujiDiamondOwner)
      .addCheckerSigners([checkerSignerAddress]);
  });

  it("#1: emitFeeCollector", async () => {
    const targetPayload =
      mockRelayFeeCollector.interface.encodeFunctionData("emitFeeCollector");
    const relayPayload = gelatoRelay.interface.encodeFunctionData(
      "callWithSyncFeeV2",
      [targetAddress, targetPayload, false, correlationId]
    );

    const msg: MessageFeeCollectorStruct = {
      service: gelatoRelay.address,
      data: relayPayload,
      salt,
      deadline,
      feeToken,
    };

    const domainSeparator = await gelatoDiamond.DOMAIN_SEPARATOR();

    const esKey = new utils.SigningKey(EXEC_SIGNER_PK);
    const csKey = new utils.SigningKey(CHECKER_SIGNER_PK);
    const digest = generateDigestFeeCollector(msg, domainSeparator);
    const executorSignerSig = utils.joinSignature(esKey.signDigest(digest));
    const checkerSignerSig = utils.joinSignature(csKey.signDigest(digest));

    const call: ExecWithSigsFeeCollectorStruct = {
      correlationId,
      msg,
      executorSignerSig,
      checkerSignerSig,
    };

    await expect(gelatoDiamond.execWithSigsFeeCollector(call))
      .to.emit(mockRelayFeeCollector, "LogMsgData")
      .withArgs(targetPayload)
      .and.to.emit(mockRelayFeeCollector, "LogFeeCollector")
      .withArgs(FEE_COLLECTOR);
  });

  it("#2: testOnlyGelatoRelay reverts if not GelatoRelay", async () => {
    await expect(
      mockRelayFeeCollector.testOnlyGelatoRelay()
    ).to.be.revertedWith("onlyGelatoRelay");
  });
});
