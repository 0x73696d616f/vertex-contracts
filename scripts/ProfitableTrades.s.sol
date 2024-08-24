// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Script} from "forge-std/src/Script.sol";
import {console2} from "forge-std/src/console2.sol";
import {Endpoint} from "../contracts/Endpoint.sol";
import {SpotEngine} from "../contracts/SpotEngine.sol";
import {IClearinghouse} from "../contracts/interfaces/clearinghouse/IClearinghouse.sol";
import {Clearinghouse} from "../contracts/Clearinghouse.sol";
import {IEndpoint} from "../contracts/interfaces/IEndpoint.sol";
import {ISpotEngine} from "../contracts/interfaces/engine/ISpotEngine.sol";
import {RiskHelper} from "../contracts/libraries/RiskHelper.sol";
import {IProductEngine} from "../contracts/interfaces/engine/IProductEngine.sol";
import {OffchainExchange} from "../contracts/OffchainExchange.sol";

contract ProfitableTrades is Script {
    Endpoint public endpoint;
    Clearinghouse public clearinghouse;
    SpotEngine public spotEngine;
    OffchainExchange public offchainExchange;

    // Pre-defined contract addresses (retrieved from /deployments)
    address public endpointAddress = 0x5623114a103798D5E49487Cee3e5EC18Fc08fAd5;
    address public clearinghouseAddress =
        0xB959143730eA6F47d5Cf7517A68066D9e33f32dA;
    address public spotEngineAddress =
        0x9F0070B572dE2453910b6B4937A1898D74E87f62;
    address public orderBookAddress =
        0xb029a23FE62FC9f0236bD7aC9921839D3E2811Cb;
    address public WONE = 0xcF664087a5bB0237a0BAd6742852ec6c8d69A27a;
    address public clearinghouseLiqAddress =
        0x73C730C83082FE7f974c71Be6aB8176DCb53282C;
    address public offchainExchangeAddress =
        0xFf9FB55A57e413240dd9A957898061e12D2E8F8a;
    address public mockSanctionsAddress =
        0x0b02aEBFe10C49ea823a21A485979aA0CF849B2e;
    address public verifierAddress = 0x4C8351a2D11fb6A23fC28E4ecB9A1a0E01553938;

    int128[] public initialPrices;

    function setUp() public {
        // Initialize contract instances using the pre-defined addresses
        endpoint = Endpoint(endpointAddress);
        clearinghouse = Clearinghouse(clearinghouseAddress);
        spotEngine = SpotEngine(spotEngineAddress);
        offchainExchange = OffchainExchange(offchainExchangeAddress);

        // Set up initial price array with sample values (in wei)
        initialPrices = new int128[](3);
        initialPrices[0] = 750000000000000000; // 0.00075 ETH (18 decimals)
        initialPrices[1] = 800000000000000000; // 0.00080 ETH (18 decimals)
        initialPrices[2] = 1000000000000000000; // 0.00001 ETH (18 decimals)
    }

    function run() external {
        uint32 productId = 6; // Product ID for WONE
        int128 amount = 10e18; // Trade amount (in wei)
        uint64 nonce = 0; // Transaction nonce

        // Add debug output to trace the current state
        console2.log("Product ID:", productId);
        console2.log("Amount:", amount);
        console2.log("Nonce:", nonce);
        console2.log("Sender:", msg.sender);

        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        // Initialize the Endpoint contract
        endpoint.initialize(
            mockSanctionsAddress, // _sanctions
            msg.sender, // _sequencer
            offchainExchangeAddress, // _offchainExchange
            IClearinghouse(clearinghouseAddress), // _clearinghouse
            verifierAddress, // _verifier
            initialPrices // initialPrices
        );

        // Initialize the Clearinghouse contract
        clearinghouse.initialize(
            endpointAddress, // _endpoint
            WONE, // _quote
            clearinghouseLiqAddress, // _clearinghouseLiq
            0
        );

        // Check if a SPOT engine is already added to the Clearinghouse, if not, add it
        address existingEngine = clearinghouse.getEngineByType(
            IProductEngine.EngineType.SPOT
        );
        if (existingEngine == address(0)) {
            clearinghouse.addEngine(
                address(spotEngine),
                address(offchainExchangeAddress),
                IProductEngine.EngineType.SPOT
            );
        }

        // Initialize the OffchainExchange contract
        offchainExchange.initialize(clearinghouseAddress, endpointAddress);

        // Add a new product to the SpotEngine
        spotEngine.addProduct(
            productId,
            address(orderBookAddress),
            1e18, // sizeIncrement
            1e16, // minSize
            1e16, // lpSpreadX18
            ISpotEngine.Config({
                token: address(WONE), // Replace with your token address
                interestInflectionUtilX18: 8e17,
                interestFloorX18: 1e16,
                interestSmallCapX18: 4e16,
                interestLargeCapX18: 1e18
            }),
            RiskHelper.RiskStore({
                longWeightInitial: 1e9,
                shortWeightInitial: 1e9,
                longWeightMaintenance: 1e9,
                shortWeightMaintenance: 1e9,
                priceX18: 1e18
            })
        );

        // Deposit collateral with a referral code
        //TODO: Currently failing due to an issue after getToken() is called
        endpoint.depositCollateralWithReferral(
            bytes32(uint256(uint160(msg.sender))),
            productId,
            uint128(amount),
            "-1" // default referral code
        );

        // Encode a MatchOrderAMM transaction for a long position
        bytes memory matchOrderAMMtransaction = abi.encodePacked(
            uint8(IEndpoint.TransactionType.MatchOrderAMM),
            abi.encode(
                IEndpoint.MatchOrderAMM({
                    productId: productId,
                    baseDelta: amount,
                    quoteDelta: int128(0),
                    taker: IEndpoint.SignedOrder({
                        order: IEndpoint.Order({
                            sender: bytes32(uint256(uint160(msg.sender))),
                            priceX18: int128(0),
                            amount: amount,
                            expiration: uint64(block.timestamp + 1 days),
                            nonce: nonce
                        }),
                        signature: ""
                    })
                })
            )
        );

        //TODO: Encode a short position broadcasting with other private key and add it to the transactions array

        // endpoint.setSequencer(msg.sender);

        // Create an array of transactions and add the encoded transaction
        bytes[] memory transactions = new bytes[](1);
        uint64 idx = endpoint.nSubmissions(); // Current submission index

        transactions[0] = matchOrderAMMtransaction; // Assign the encoded transaction to the first slot

        console2.log("Current submission index:", idx);
        uint256 gasLimit = 100000000;

        // Submit the transaction array with the specified gas limit
        endpoint.submitTransactionsCheckedWithGasLimit(
            idx,
            transactions,
            gasLimit
        );

        console2.log("Submitted long position with gas limit");

        // TODO: Close positions to demonstrate profitability

        vm.stopBroadcast();
    }
}
