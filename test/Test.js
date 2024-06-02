const { expect } = require("chai");
const { ethers } = require("hardhat");

const {
    loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");

describe("Test suite for contract Ownable.sol", function () {
    async function deployTokenFixture() {
        const [owner, newOwner, addr1] = await ethers.getSigners();
        const ownable = await ethers.deployContract("Ownable");
        await ownable.waitForDeployment();
        return { ownable, owner, newOwner, addr1 };
    }

    describe("onlyOwner modifier", function () {
        it("should not allow a non-owner to call restricted function", async function () {
            const { ownable, owner, newOwner, addr1 } = await loadFixture(deployTokenFixture);
            await expect(
                ownable.connect(addr1).transferOwnership(addr1)
            ).to.be.revertedWith("Caller is not the owner");
        });

        it("should allow the owner to transfer ownership", async function () {
            const { ownable, owner, newOwner, addr1 } = await loadFixture(deployTokenFixture);
            await expect(ownable.transferOwnership(newOwner)).to.not.be.reverted;
            await expect(
                ownable.connect(owner).transferOwnership(addr1)
            ).to.be.revertedWith("Caller is not the owner");
        });
    });
});

describe("Test suite for contract Contract.sol", function () {
    async function deployTokenFixture() {
        const [owner, addr1, addr2] = await ethers.getSigners();
    
        const initialNumberOfLanes = 3;
        const initialMaxCapacityByLane = 10;
        const initialValidityTime = 60;
        
        const RailroadCrossing = await ethers.getContractFactory("RailroadCrossing");
        const contract = await RailroadCrossing.deploy(initialNumberOfLanes, initialMaxCapacityByLane, initialValidityTime);
        await contract.waitForDeployment();
        
        return { contract, owner, addr1, addr2 , initialNumberOfLanes, initialMaxCapacityByLane, initialValidityTime };
    }

    describe("getLaneCapacity", function () {
        it("should return the correct lane capacity", async function () {
            const { contract, owner, addr1, addr2 , initialNumberOfLanes, initialMaxCapacityByLane, initialValidityTime } = await loadFixture(deployTokenFixture);
            expect(await contract.getLaneCapacity(1)).to.equal(0);
            await contract.noTrainUpdate();
            await contract.connect(addr1).tryToEnterLane(0);
            await contract.connect(addr2).tryToEnterLane(0);
            expect(await contract.getLaneCapacity(0)).to.equal(2);
        });
    });

    describe("laneHasCapacity", function () {
        it("should return true if lane has capacity", async function () {
            const { contract, owner, addr1, addr2 , initialNumberOfLanes, initialMaxCapacityByLane, initialValidityTime } = await loadFixture(deployTokenFixture);
            expect(await contract.laneHasCapacity(0)).to.be.true;
        });

        it("should return false if lane does not have capacity", async function () {
            const { contract, owner, addr1, addr2 , initialNumberOfLanes, initialMaxCapacityByLane, initialValidityTime } = await loadFixture(deployTokenFixture);
            await contract.setMaxCapacityOfLane(0, 2);
            await contract.noTrainUpdate();
            await contract.connect(addr1).tryToEnterLane(0);
            await contract.connect(addr2).tryToEnterLane(0);
            expect(await contract.laneHasCapacity(0)).to.be.false;
        });
    });

    describe("getNumberOfLanes", function () {
        it("should return the correct number of lanes", async function () {
            const { contract, owner, addr1, addr2 , initialNumberOfLanes, initialMaxCapacityByLane, initialValidityTime } = await loadFixture(deployTokenFixture);
            expect(await contract.getNumberOfLanes()).to.equal(initialNumberOfLanes);
            await contract.addLane(initialMaxCapacityByLane);
            expect(await contract.getNumberOfLanes()).to.equal(initialNumberOfLanes + 1);
        });
    });

    describe("setValidityTime", function () {
        it("should set the correct validity time", async function () {
            const { contract, owner, addr1, addr2 , initialNumberOfLanes, initialMaxCapacityByLane, initialValidityTime } = await loadFixture(deployTokenFixture);
            await contract.setValidityTime(100);
            expect(await contract.getValidityTime()).to.equal(100);
        });
    });

    describe("setMaxCapacityOfLane", function () {
        it("should set max capacity of a lane", async function () {
            const { contract, owner, addr1, addr2 , initialNumberOfLanes, initialMaxCapacityByLane, initialValidityTime } = await loadFixture(deployTokenFixture);
            await contract.setMaxCapacityOfLane(0, 200);
            expect(await contract.getMaxCapacityOfLane(0)).to.equal(200);
        });
    });

    describe("onlyOwner functions", function () {
        it("should not allow non-owner to set validity time", async function () {
            const { contract, owner, addr1, addr2 , initialNumberOfLanes, initialMaxCapacityByLane, initialValidityTime } = await loadFixture(deployTokenFixture);
            await expect(
                contract.connect(addr1).setValidityTime(100)
            ).to.be.revertedWith("Caller is not the owner");
        });

        it("should not allow non-owner to set number of lanes", async function () {
            const { contract, owner, addr1, addr2 , initialNumberOfLanes, initialMaxCapacityByLane, initialValidityTime } = await loadFixture(deployTokenFixture);
            await expect(
                contract.connect(addr1).addLane(initialNumberOfLanes)
            ).to.be.revertedWith("Caller is not the owner");
        });

        it("should not allow non-owner to set max capacity of a lane", async function () {
            const { contract, owner, addr1, addr2 , initialNumberOfLanes, initialMaxCapacityByLane, initialValidityTime } = await loadFixture(deployTokenFixture);
            await expect(
                contract.connect(addr1).setMaxCapacityOfLane(0, 200)
            ).to.be.revertedWith("Caller is not the owner");
        });
    });

    describe("_checkTrainCanPass", function () {
        it("should return false if any lane is not in LOCKED state", async function () {
            const { contract, owner, addr1, addr2 , initialNumberOfLanes, initialMaxCapacityByLane, initialValidityTime } = await deployTokenFixture();

            // for (let index = 0; index < await contract.getNumberOfLanes(); index++) {
            //     console.log(await contract.getLaneState(index));
            // }

            // await contract.noTrainUpdate();

            // for (let index = 0; index < await contract.getNumberOfLanes(); index++) {
            //     console.log(await contract.getLaneState(index));
            // }
            
            expect(await contract.checkTrainCanPass()).to.be.true;
        });
    
        it("should return true if all lanes are in LOCKED state", async function () {
            const { contract, owner, addr1, addr2 , initialNumberOfLanes, initialMaxCapacityByLane, initialValidityTime } = await deployTokenFixture();
            await contract.noTrainUpdate();
            expect(await contract.checkTrainCanPass()).to.be.false;
        });
    });

    describe("infrastructure updates", function () {
        it("should emit TrainComing event and update lane states correctly", async function () {
            const { contract, owner, addr1, addr2 , initialNumberOfLanes, initialMaxCapacityByLane, initialValidityTime } = await deployTokenFixture();

            await expect(contract.trainComing()).to.emit(contract, "TrainComing");

            for (let i = 0; i < initialNumberOfLanes; i++) {
                const laneState = await contract.getLaneState(i);
                expect(laneState).to.equal(1 /* State.LOCKED */);
            }
        });
        
        it("should emit TrainPassed event and update lane states correctly", async function () {
            const { contract, owner, addr1, addr2 , initialNumberOfLanes, initialMaxCapacityByLane, initialValidityTime } = await deployTokenFixture();
            await expect(contract.trainGone()).to.emit(contract, "TrainPassed");

            for (let i = 0; i < initialNumberOfLanes; i++) {
                const laneState = await contract.getLaneState(i);
                expect(laneState).to.equal(0 /* State.FREE_TO_CROSS */);
            }
        });
        
        it("should update lane states correctly when no train is coming", async function () {
            const { contract, owner, addr1, addr2 , initialNumberOfLanes, initialMaxCapacityByLane, initialValidityTime } = await deployTokenFixture();

            for (let i = 0; i < initialNumberOfLanes; i++) {
                const laneState = await contract.getLaneState(i);
                expect(laneState).to.equal(1 /* State.LOCKED */);
            }

            await contract.noTrainUpdate();

            for (let i = 0; i < initialNumberOfLanes; i++) {
                const laneState = await contract.getLaneState(i);
                expect(laneState).to.equal(0 /* State.FREE_TO_CROSS */);
            }
        });
    });

    describe("car permission updates", function () {
        it("should allow a car to enter a lane and update lane capacity", async function () {
            const { contract, owner, addr1, addr2 , initialNumberOfLanes, initialMaxCapacityByLane, initialValidityTime } = await deployTokenFixture();
            
            await expect(
                contract.connect(addr1).tryToEnterLane(0)
            ).to.be.revertedWith("Crossing is blocked!");

            await contract.noTrainUpdate();
            await contract.connect(addr1).tryToEnterLane(0);
        
            // Check if car is now in the lane
            expect(await contract.carIsInLane(addr1)).to.be.true;
            expect(await contract.laneOfCar(addr1)).to.equal(0);
            expect(await contract.getLaneCapacity(0)).to.equal(1);

            await expect(
                contract.connect(addr1).tryToEnterLane(0)
            ).to.be.revertedWith("Car is already in a lane!");
        });
        
        it("should grant permission to a car and update ledger", async function () {
            const { contract, owner, addr1, addr2 , initialNumberOfLanes, initialMaxCapacityByLane, initialValidityTime } = await deployTokenFixture();
            await expect(
                contract.connect(addr1).requestPermission()
            ).to.be.revertedWith("Car is not in a lane!");

            await contract.noTrainUpdate();
            await contract.connect(addr1).tryToEnterLane(0);

            await contract.trainComing();
        
            await expect(
                contract.connect(addr1).requestPermission()
            ).to.be.revertedWith("Crossing is locked!");
            
            await contract.noTrainUpdate();
            await contract.connect(addr1).requestPermission();
            
            expect(await contract.carHasPermission(addr1)).to.be.true;
        
            // Check if permission is recorded in the ledger
            const ledgerEntry = await contract.ledger(0);
            expect(ledgerEntry[3]).to.equal(1 /*PERMISSION_GIVEN*/);
            expect(ledgerEntry[0]).to.equal(addr1);
            expect(ledgerEntry[1]).to.equal(0);
        });
        
        it("should allow a car to enter the crossing and update ledger", async function () {
            const { contract, owner, addr1, addr2 , initialNumberOfLanes, initialMaxCapacityByLane, initialValidityTime } = await deployTokenFixture();
            await contract.noTrainUpdate();
            
            await expect(
                contract.connect(addr1).carEnter()
            ).to.be.revertedWith("Car is not in a lane!");
            
            await contract.connect(addr1).tryToEnterLane(0);

            await expect(
                contract.connect(addr1).carEnter()
            ).to.be.revertedWith("No permission to enter!");

            await contract.connect(addr1).requestPermission();
            await contract.trainComing();

            await expect(
                contract.connect(addr1).carEnter()
            ).to.be.revertedWith("Crossing is locked!");
            
            await contract.noTrainUpdate();

            contract.connect(addr1).carEnter()
            
            expect(await contract.carIsInLane(addr1)).to.be.true;

            const laneState = await contract.getLaneState(0);
            expect(laneState).to.equal(2 /* State.OCCUPIED */);

            // console.log(await contract.ledger(1));
            const ledgerEntry = await contract.ledger(1);
            expect(ledgerEntry[3]).to.equal(0 /*ENTERED_CROSSING*/);
            expect(ledgerEntry[0]).to.equal(addr1);
            expect(ledgerEntry[1]).to.equal(0);
        });
        
        it("should allow a car to leave the crossing and update lane state", async function () {
            const { contract, owner, addr1, addr2 , initialNumberOfLanes, initialMaxCapacityByLane, initialValidityTime } = await deployTokenFixture();

            await contract.noTrainUpdate();
            
            await contract.connect(addr1).tryToEnterLane(0);
            await contract.connect(addr1).requestPermission();
            await contract.connect(addr1).carEnter();

            await expect(
                contract.connect(addr1).carLeave(0, addr1)
            ).to.be.revertedWith("Caller is not the owner");

            contract.carLeave(0, addr1);

            const ledgerEntry = await contract.ledger(2);
            expect(ledgerEntry[3]).to.equal(2 /*PERMISSION_REMOVED*/);
            expect(ledgerEntry[0]).to.equal(addr1);
            expect(ledgerEntry[1]).to.equal(0);
        });
    });

    describe("complex test cases", function () {
        it("should update lane states while cars and trains are coming and going", async function () {
            const { contract, owner, addr1, addr2 , initialNumberOfLanes, initialMaxCapacityByLane, initialValidityTime } = await deployTokenFixture();
            await contract.noTrainUpdate();
            await contract.connect(addr1).tryToEnterLane(0);
            await contract.connect(addr1).requestPermission();
            await contract.connect(addr1).carEnter();

            await expect(contract.trainComing()).to.not.emit(contract, "TrainCanPass");
            
            const laneState = await contract.getLaneState(0);
            expect(laneState).to.equal(3 /* State.OCCUPIED_AND_LOCKING */);

            await expect(contract.carLeave(0, addr1)).to.emit(contract, "TrainCanPass");
            await expect(contract.trainGone()).to.emit(contract, "TrainPassed");
        });
    
        it("car2 should block the way for car1", async function () {
            const { contract, owner, addr1, addr2 , initialNumberOfLanes, initialMaxCapacityByLane, initialValidityTime } = await deployTokenFixture();
            await contract.noTrainUpdate();

            await contract.connect(addr2).tryToEnterLane(0);
            await contract.connect(addr2).requestPermission();
            
            await contract.connect(addr1).tryToEnterLane(0);
            await contract.connect(addr1).requestPermission();

            await contract.connect(addr2).carEnter();

            await expect(
                contract.connect(addr1).carEnter()
            ).to.be.revertedWith("Crossing is blocked by another car!");

            await expect(
                contract.connect(addr1).carLeave(0, addr1)
            ).to.be.revertedWith("Caller is not the owner");

            await contract.carLeave(0, addr2)

            const ledgerEntry = await contract.ledger(3);
            expect(ledgerEntry[3]).to.equal(2 /*PERMISSION_REMOVED*/);
            expect(ledgerEntry[0]).to.equal(addr2);
            expect(ledgerEntry[1]).to.equal(0);

            await contract.connect(addr1).carEnter();

            const ledgerEntry2 = await contract.ledger(4);
            expect(ledgerEntry2[3]).to.equal(0 /*ENTERED_CROSSING*/);
            expect(ledgerEntry2[0]).to.equal(addr1);
            expect(ledgerEntry2[1]).to.equal(0);

            await contract.carLeave(0, addr1)

            const ledgerEntry3 = await contract.ledger(5);
            expect(ledgerEntry3[3]).to.equal(2 /*PERMISSION_REMOVED*/);
            expect(ledgerEntry3[0]).to.equal(addr1);
            expect(ledgerEntry3[1]).to.equal(0);
        });

        it("train goes trough crossing and car enters only after", async function () {
            const { contract, owner, addr1, addr2 , initialNumberOfLanes, initialMaxCapacityByLane, initialValidityTime } = await deployTokenFixture();

            await contract.noTrainUpdate();

            await contract.connect(addr1).tryToEnterLane(0);
            await contract.connect(addr1).requestPermission();

            await expect(contract.trainComing()).to.emit(contract, "TrainCanPass");

            await expect(
                contract.connect(addr1).carEnter()
            ).to.be.revertedWith("Crossing is locked!");

            await expect(contract.trainGone()).to.emit(contract, "TrainPassed");

            await expect(contract.connect(addr1).carEnter()).to.emit(contract, "LaneOccupied").withArgs(0);
            await expect(contract.carLeave(0, addr1)).to.emit(contract, "LaneFree").withArgs(0);
        });

        it("lane capacity gets full and car cannot enter", async function () {
            const { contract, owner, addr1, addr2 , initialNumberOfLanes, initialMaxCapacityByLane, initialValidityTime } = await deployTokenFixture();
            await contract.noTrainUpdate();
            await contract.setMaxCapacityOfLane(0, 1);

            expect(await contract.laneHasCapacity(0)).to.be.true;

            await contract.connect(addr1).tryToEnterLane(0);

            expect(await contract.laneHasCapacity(0)).to.be.false;

            await expect(contract.connect(addr2).tryToEnterLane(0)).to.be.revertedWith("Lane is full!");
        });
    });
});
