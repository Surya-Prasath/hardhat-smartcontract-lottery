const {network} = require("hardhat");
const { developmentChains, networkConfig } = require("../helper-hardhat-config");   
const {verify} = require("../hardhat.config")

// deploy/00_deploy_my_contract.js
module.exports = async ({getNamedAccounts, deployments}) => {
    const {deploy, log} = deployments;
    const {deployer} = await getNamedAccounts();
    const chainId = network.config.chainId
    let vrfCoordinatorV2Address, subscriptionId;

    if(developmentChains.includes(network.name)){
        const VRFCoordinatorV2Mock = await ethers.getContract("VRFCoordinatorV2Mock");
        vrfCoordinatorV2Address = VRFCoordinatorV2Mock.address;

        const transactionResponse = await VRFCoordinatorV2Mock.createSubscription();
        const transactionReceipt = await transactionResponse.wait(1);
        subscriptionId = transactionReceipt.events[0].args.subId;

        //Fund the subscription
        await VRFCoordinatorV2Mock.fundSubscription(subscriptionId, ethers.utils.parseEther("2"));

    } else {
        vrfCoordinatorV2Address = networkConfig[chainId].vrfCoordinatorV2Address;
        subscriptionId = networkConfig[chainId].subscriptionId;
    }

    const entranceFee = networkConfig[chainId].entranceFee;
    const gasLane = networkConfig[chainId].gasLane;
    const callbackGasLimit = networkConfig[chainId].callbackGasLimit;
    const interval = networkConfig[chainId].interval;

    const args = [
        vrfCoordinatorV2Address, 
        entranceFee, 
        gasLane,
        subscriptionId, 
        callbackGasLimit, 
        interval
    ]
    
    const raffle = await deploy("Raffle", {
        from: deployer,
        args: args,
        log: true,
        waitConfirmations: network.config.blockConfirmations || 1
    })

    if(!developmentChains.includes(network.config.chainId) && process.env.ETHERSCAN_API_KEY){
        log("Verifying...")
        await verify(raffle.address, args)
    }

    log("----------------------------")

  };

  module.exports.tags = ["all", 'Raffle'];
