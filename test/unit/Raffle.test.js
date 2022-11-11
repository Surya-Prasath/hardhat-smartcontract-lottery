const { network, getNamedAccounts, deployments, ethers } = require("hardhat")
const { assert, expect } = require("chai")
const {developmentChains, networkConfig} = require("../../helper-hardhat-config")

!developmentChains.includes(network.name) ? describe.skip :
        describe("Raffle Unit tests", async function(){
            let raffle, VRFCoordinatorV2Mock, raffleEntranceFee, deployer, interval
            const chainId = network.config.chainId

            beforeEach(async function(){
                deployer = (await getNamedAccounts()).deployer
                await deployments.fixture(["all"])
                raffle = await ethers.getContract("Raffle", deployer)
                VRFCoordinatorV2Mock = await ethers.getContract("VRFCoordinatorV2Mock", deployer)
                raffleEntranceFee = await raffle.getEntranceFee()
                interval = await raffle.getInterval()

            })

            describe("constructor", async function(){
                it("Initializes the raffle correctly", async function(){
                    const raffleState = await raffle.getRaffleState()
                    assert.equal(raffleState.toString(), "0")
                    assert.equal(interval.toString(), networkConfig[chainId].interval)
                })
            })

            describe("enterRaffle", async function(){
                it("reverts when you don't pay enough", async function(){
                    await expect(raffle.enterRaffle()).to.be.revertedWith("Raffle_NotEnoughETHEntered")
                })

                it("record players when they enter", async function(){
                    await raffle.enterRaffle({value: raffleEntranceFee})
                    const playerFromContract = await raffle.getPlayer(0)
                    assert.equal(playerFromContract, deployer)
                })

                it("emits event on enter", async function(){
                    await expect(raffle.enterRaffle({value: raffleEntranceFee})).to.emit(raffle, "RaffleEnter")
                })

                it("Doesn't allow entrance when raffle is calculating", async function(){
                    await raffle.enterRaffle({value: raffleEntranceFee})
                    await network.provider.send("evm_increaseTime", [interval.toNumber()+1])
                    await network.provider.send("evm_mine", [])
                    
                    raffle.performUpkeep([]).then(async()=>{
                        await expect(raffle.enterRaffle({value: raffleEntranceFee})).to.be.revertedWith("Raffle_NotOpen")
                    })
                })
            })

            describe("checkUpkeep", async function(){
                it("returns false if people haven't sent any ETH", async function(){
                    await network.provider.send("evm_increaseTime", [interval.toNumber()+1])
                    await network.provider.send("evm_mine", [])
                    const {upkeepNeeded} = await raffle.callStatic.checkUpkeep([])
                    assert(!upkeepNeeded)
                })

                it("returns false if raffle isn't open", async function(){
                    await raffle.enterRaffle({value: raffleEntranceFee})
                    await network.provider.send("evm_mine", [])
                    raffle.performUpkeep([]).then(async()=>{
                        const raffleState = await raffle.getRaffleState()
                        const {upkeepNeeded} = raffle.callStatic.checkUpkeep([])
                        assert.equal(raffleState.toString(), "1")
                        assert.equal(upkeepNeeded, false)
                        })
                    })
                })
           
            })

    