// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mocks/MockLink.sol";

abstract contract CodeConstants {
    /** VRF Mock Values */
    uint96 public MOCK_BASE_FEE = 0.25 ether;
    uint96 public MOCK_GAS_PRICE_LINK = 1e9;
    // LINK / ETH price
    int256 public MOCK_WEI_PER_UINT_LINK = 4e15;

    uint256 public constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant LOCAL_CHAIN_ID = 31337;
}


contract HelperConfig is CodeConstants, Script {
    error HelperConfig__InvalidChainId();

    struct NetworkConfig{
        uint256 entranceFee; 
        uint256 interval;
        address vrfCoordinator; 
        bytes32 gasLane; 
        uint256 subscriptionId; 
        uint32 callbackGasLimit;
        address link;
        // we need to add an account for our forked testnet or real testnet account that is equal to the address who created the subscription id -> I created the subscription manually with my metamask wallet account, need to add it here!
        address account; 
    }

    NetworkConfig public localNetworkConfig;
    mapping(uint256 chainId => NetworkConfig) public networkConfigs; // ?? whats the use of this mapping when in our deploy script we call getConfig -> calls getConfigByChainId -> returns the struct for the anvil chain directly in case of local without the struct networkConfigs needed/used??

    constructor() {
        networkConfigs[ETH_SEPOLIA_CHAIN_ID] = getSepoliaEthConfig(); // ?? why this line? why saving eth_sepolia_chain_ID to to networks config struct?
    }

    function getConfigByChainId(uint256 chainId) public returns (NetworkConfig memory) {
        if(networkConfigs[chainId].vrfCoordinator != address(0)){
            return networkConfigs[chainId];
        } else if (chainId == LOCAL_CHAIN_ID) {
            return getOrCreateAnvilEthConfig();
        } else {
            revert HelperConfig__InvalidChainId();
        }
    }

    function getConfig() public returns (NetworkConfig memory) {
        return getConfigByChainId(block.chainid);

    }

    function getSepoliaEthConfig() public returns (NetworkConfig memory) {
        return NetworkConfig({
        entranceFee:  0.01 ether,
        interval: 30, // 30 seconds
        vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
        gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
        subscriptionId: 56619989257250452055161964266403623815909640180300137700302182873658985253701, 
        callbackGasLimit: 500000,
        link: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
        // here I add my actual account that manually created the subscription id on chainlink website, so that we have permission to add a consumer to the subscription id
        account: vm.envAddress("ACCOUNT_ADDRESS")  
        }); 
    }

    function getOrCreateAnvilEthConfig() public returns(NetworkConfig memory){
        // check to see if we set an active network config

        if (localNetworkConfig.vrfCoordinator != address(0)){
            return localNetworkConfig;
        }

        vm.startBroadcast();
        // here we deploy our VRF mock coordinator contract that selects our random number and calls our raffle contract on anvil, thats not needed on a real testnet ass chainlink had already deployed the vrfmock contract!
        VRFCoordinatorV2_5Mock vrfCoordinatorMock = new VRFCoordinatorV2_5Mock(MOCK_BASE_FEE,MOCK_GAS_PRICE_LINK,MOCK_WEI_PER_UINT_LINK);
        LinkToken linkToken = new LinkToken(); // we also need to deploy the LinkToken as a mock on anvil, as we need to fund the vrfCoordinatorMock above
        vm.stopBroadcast();

        localNetworkConfig = NetworkConfig({
            entranceFee: 0.01 ether,
            interval: 30,         
            vrfCoordinator: address(vrfCoordinatorMock),
            // the below does not matter for the mock, we could use any address
            gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            subscriptionId: 0, 
            callbackGasLimit: 500000,
            link: address(linkToken),
            account:  0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38 // default sender of the foundry anvil local testing, whenever we need to use an account address locally
        });

        return localNetworkConfig;
    }
}