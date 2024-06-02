// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.24;

import "./Ownable.sol";

contract RailroadCrossing is Ownable {

    event TrainComing();
    event TrainCanPass();
    event TrainPassed();
    event LaneOccupied(uint laneIndex);
    event LaneFree(uint laneIndex);

    mapping (address => bool) public carHasPermission;
    mapping (address => Permission) public permissionOfAddress;
    mapping (address => uint) public laneOfCar;
    // mapping (uint => Lane) public lanes;
    mapping (address => bool) public carIsInLane;

    // states of a train crossing
    enum State { FREE_TO_CROSS, LOCKED, OCCUPIED, OCCUPIED_AND_LOCKING }
    // FREE_TO_CROSS: nincs vonat es auto a keresztezodesben es vonat nem is erkezik
    // LOCKED: van vagy erkezik vonat es nincs auto a keresztezodesben
    // OCCUPIED: auto van a keresztezodesben nem jon vonat
    // OCCUPIED_AND_LOCKING: auto van a keresztezodesben es jon vonat, vagy nem erkezik frissites -> nem johet tobb auto

    enum RegistryEvent { ENTERED_CROSSING, PERMISSION_GIVEN, PERMISSION_REMOVED }

    struct Registry {
        address vehicleAddress;
        uint lane;
        uint time;
        RegistryEvent registryEvent;
        Permission permission;
    }

    uint public lastInfrastructureUpdate;
    uint public validityTime;
    uint public numberOfLanes;

    struct Permission {
        address vehicleAddress;
        uint lane;
        uint expirationDate;
    }

    struct Lane {
        State state;
        uint capacity;
        uint maxCapacity;
    }

    Lane[] public lanes;

    Registry[] public ledger;

    constructor(uint _numberOfLanes, uint _maxCapacityByLane, uint _validityTime) {
        validityTime = _validityTime;
        numberOfLanes = _numberOfLanes;
        for (uint i = 0; i < _numberOfLanes; i++) {
            lanes.push(Lane(State.LOCKED, 0, _maxCapacityByLane));
        }
    }

    function getLaneCapacity(uint _laneId) public view returns (uint) {
        return lanes[_laneId].capacity;
    }

    function laneHasCapacity(uint _laneId) public view returns (bool) {
        return lanes[_laneId].capacity < lanes[_laneId].maxCapacity;
    }

    function getNumberOfLanes() public view returns (uint) {
        return numberOfLanes;
    }

    function addLane(uint _maxCapacityByLane) external onlyOwner {
        numberOfLanes++;
        lanes.push(Lane(State.LOCKED, 0, _maxCapacityByLane));
    }

    function removeLane() external onlyOwner {
        numberOfLanes--;
        lanes.pop();
    }
    
    function getValidityTime() public view returns (uint) {
        return validityTime;
    }

    function setValidityTime(uint _validityTime) external onlyOwner {
        validityTime = _validityTime;
    }

    function getMaxCapacityOfLane(uint _laneId) public view returns (uint) {
        return lanes[_laneId].maxCapacity;
    }

    function setMaxCapacityOfLane(uint _laneId, uint _maxCapacity) external onlyOwner {
        require(_laneId < numberOfLanes, "Lane does not exist!");
        lanes[_laneId].maxCapacity = _maxCapacity;
    }

    function getLaneState(uint _laneId) public view returns (State) {
        return lanes[_laneId].state;
    }

    function checkTrainCanPass() public view returns (bool) {
        for (uint i = 0; i < numberOfLanes; i++) {
            if (getLaneState(i) != State.LOCKED) {
                return false;
            }
        }
        // emit TrainCanPass();
        return true;
    }

    // infrastructure signals train coming
    function trainComing() external onlyOwner {
        emit TrainComing();
        for (uint i = 0; i < numberOfLanes; i++) {
            if (lanes[i].state == State.FREE_TO_CROSS) {
                lanes[i].state = State.LOCKED;
            } else if (lanes[i].state == State.OCCUPIED) {
                lanes[i].state = State.OCCUPIED_AND_LOCKING;
            }
        }
        if (checkTrainCanPass()) {
            emit TrainCanPass();
        }
        lastInfrastructureUpdate = block.timestamp;
    }

    // infrastructure signals train has left
    function trainGone() external onlyOwner {
        for (uint i = 0; i < numberOfLanes; i++) {
            lanes[i].state = State.FREE_TO_CROSS;
        }
        emit TrainPassed();
        lastInfrastructureUpdate = block.timestamp;
    }

    // infrastructure confirms that no train is coming
    function noTrainUpdate() public onlyOwner {
        for (uint i = 0; i < numberOfLanes; i++) {
            if (lanes[i].state == State.LOCKED) {
                lanes[i].state = State.FREE_TO_CROSS;
            }
        }
        lastInfrastructureUpdate = block.timestamp;
    }

    // car tries to enter lane
    function tryToEnterLane(uint _laneId) external {
        require(lanes[_laneId].capacity < lanes[_laneId].maxCapacity, "Lane is full!");
        require(carIsInLane[msg.sender] == false, "Car is already in a lane!");
        require(lanes[_laneId].state == State.FREE_TO_CROSS || lanes[_laneId].state == State.OCCUPIED, "Crossing is blocked!");
        carIsInLane[msg.sender] = true;
        lanes[_laneId].capacity++;
        laneOfCar[msg.sender] = _laneId;
    }

    // car requests permission
    function requestPermission() external {
        uint laneId = laneOfCar[msg.sender];

        require(carIsInLane[msg.sender], "Car is not in a lane!");
        require(lastInfrastructureUpdate + validityTime > block.timestamp, "Infrastructure not responding, crossing is locked!");
        require(lanes[laneId].state == State.FREE_TO_CROSS || lanes[laneId].state == State.OCCUPIED, "Crossing is locked!");

        Permission memory newPermission = Permission(msg.sender, laneId, block.timestamp + validityTime);

        carHasPermission[msg.sender] = true;
        permissionOfAddress[msg.sender] = newPermission;
        ledger.push(Registry(msg.sender, laneId, block.timestamp, RegistryEvent.PERMISSION_GIVEN, newPermission));
    }

    // car uses permission to enter crossing
    function carEnter() external {
        uint laneId = laneOfCar[msg.sender];

        require(carIsInLane[msg.sender], "Car is not in a lane!");
        require(lastInfrastructureUpdate + validityTime > block.timestamp, "Infrastructure not responding, crossing is locked!");
        require(carHasPermission[msg.sender] == true, "No permission to enter!");
        require(block.timestamp < permissionOfAddress[msg.sender].expirationDate, "Permission expired!");
        require(lanes[laneId].state != State.LOCKED && lanes[laneId].state != State.OCCUPIED_AND_LOCKING, "Crossing is locked!");
        require(lanes[laneId].state != State.OCCUPIED, "Crossing is blocked by another car!");
        require(laneOfCar[msg.sender] == permissionOfAddress[msg.sender].lane, "Permission is not for this lane!");

        ledger.push(Registry(msg.sender, laneId, block.timestamp, RegistryEvent.ENTERED_CROSSING, permissionOfAddress[msg.sender]));

        // take permission and mark lane as occupied
        carHasPermission[msg.sender] = false;
        // permissionOfAddress[msg.sender] = Permission();
        lanes[laneId].state = State.OCCUPIED;

        ledger.push(Registry(msg.sender, laneId, block.timestamp, RegistryEvent.PERMISSION_REMOVED, permissionOfAddress[msg.sender]));

        emit LaneOccupied(laneId);
    }

    // infrastructure signals car left crossing
    function carLeave(uint _laneId, address _vehicleAddress) external onlyOwner {
        if (lanes[_laneId].state == State.OCCUPIED) {
            lanes[_laneId].state = State.FREE_TO_CROSS;
        } else if (lanes[_laneId].state == State.OCCUPIED_AND_LOCKING) {
            lanes[_laneId].state = State.LOCKED;
            if (checkTrainCanPass()) {
                emit TrainCanPass();
            }
        }

        lanes[_laneId].capacity--;
        delete laneOfCar[_vehicleAddress];

        lastInfrastructureUpdate = block.timestamp;

        emit LaneFree(_laneId);
    }
}
