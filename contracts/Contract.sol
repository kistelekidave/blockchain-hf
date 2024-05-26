pragma solidity >=0.5.0 <0.6.0;

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
    mapping (uint => Lane) public lanes;

    // states of a train crossing
    enum State { FREE_TO_CROSS, LOCKED, OCCUPIED, OCCUPIED_AND_LOCKING };
    // FREE_TO_CROSS: nincs vonat es auto a keresztezodesben es vonat nem is erkezik
    // LOCKED: van vagy erkezik vonat es nincs auto a keresztezodesben
    // OCCUPIED: auto van a keresztezodesben nem jon vonat
    // OCCUPIED_AND_LOCKING: auto van a keresztezodesben es jon vonat, vagy nem erkezik frissites -> nem johet tobb auto

    enum RegistryEvent { ENTERED_CROSSING, PERMISSION_GIVEN, PERMISSION_REMOVED };

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

    Registry[] public ledger;

    constructor(uint _numberOfLanes, uint _maxCapacityByLane, uint _validityTime) {
        validityTime = _validityTime;
        numberOfLanes = _numberOfLanes;
        for (uint i = 0; i < _numberOfLanes; i++) {
            lanes[i] = Lane(state=State.FREE_TO_CROSS, capacity=0, maxCapacity=_maxCapacityByLane);
        }
    }

    function getLaneCapacity(uint calldata _laneId) public view returns (uint) {
        return lanes[_laneId].capacity;
    }

    function laneHasCapacity(uint calldata _laneId) public view returns (bool) {
        return lanes[_laneId].capacity < lanes[_laneId].maxCapacity;
    }

    function getNumberOfLanes() public view returns (uint) {
        return numberOfLanes;
    }

    function setValidityTime(uint _validityTime) external onlyOwner {
        validityTime = _validityTime;
    }

    function setNumberOfLanes(uint _numberOfLanes) external onlyOwner {
        numberOfLanes = _numberOfLanes;
    }

    function setMaxCapacityOfLane(uint _laneId, uint _maxCapacity) external onlyOwner {
        lanes[_laneId].maxCapacity = _maxCapacity;
    }

    function _checkTrainCanPass() internal view returns (bool) {
        for (uint i = 0; i < _numberOfLanes; i++) {
            if (lanes[i].state != State.LOCKED) {
                return false;
            }
        }
        emit TrainCanPass();
        return true;
    }

    // infrastructure signals train coming
    function trainComing() external onlyOwner {
        emit TrainComing();
        for (uint i = 0; i < _numberOfLanes; i++) {
            if (lanes[_laneId].state == State.FREE_TO_CROSS) {
                lanes[_laneId].state = State.LOCKED;
            } else if (lanes[_laneId].state == State.OCCUPIED) {
                lanes[_laneId].state = State.OCCUPIED_AND_LOCKING;
            }
        }
        _checkTrainCanPass();
        lastInfrastructureUpdate = now;
    }

    // infrastructure signals train has left
    function trainGone(uint _laneId) external onlyOwner {
        for (uint i = 0; i < _numberOfLanes; i++) {
            lanes[_laneId].state == State.FREE_TO_CROSS;
        }
        emit TrainPassed();
        lastInfrastructureUpdate = now;
    }

    // infrastructure confirms that no train is coming
    function noTrainUpdate() public onlyOwner {
        for (uint i = 0; i < _numberOfLanes; i++) {
            if (lanes[i].state == State.LOCKED) {
                lanes[i].state = State.FREE_TO_CROSS;
            }
        }
        lastInfrastructureUpdate = now;
    }

    // car tries to enter lane
    function tryToEnterLane(uint _laneId) external {
        require(!laneOfCar(msg.sender), "Car is already in a lane!");
        require(lanes[_laneId].state == State.FREE_TO_CROSS, "Crossing is blocked!");
        lanes[_laneId].capacity++;
        laneOfCar[msg.sender] = _laneId;
    }

    // car requests permission
    function requestPermission() external {
        uint laneId = laneOfCar[msg.sender];

        require(lanes[laneId].capacity < lanes[laneId].maxCapacity, "Lane is full!");
        require(lastInfrastructureUpdate + validityTime < now, "Infrastructure not responding, crossing is locked!");
        require(lanes[laneId].state == State.FREE_TO_CROSS || lanes[laneId].state == State.OCCUPIED, "Train coming!");

        Permission newPermission = Permission(vehicleAddress=msg.sender, lane=laneId, expirationDate=now + validityTime);

        ownerHasPermission[msg.sender] = true;
        permissionOfAddress[msg.sender] = newPermission;
        ledger.push(Registry(vehicleAddress=msg.sender, lane=laneId, time=now, registryEvent=RegistryEvent.PERMISSION_GIVEN, permission=newPermission));
    }

    // car uses permission to enter crossing
    function carEnter(uint _laneId) external {
        uint laneId = laneOfCar[msg.sender];

        require(lastInfrastructureUpdate + validityTime < now, "Infrastructure not responding, crossing is locked!");
        require(ownerHasPermission[msg.sender] == true, "No permission to enter!");
        require(now < permissionOfAddress[msg.sender].expirationDate, "Permission expired!");
        require(lanes[laneId].state == State.FREE_TO_CROSS, "Crossing is blocked!");
        require(laneOfCar[msg.sender] == permissionOfAddress[msg.sender].lane, "Permission is not for this lane!");

        ledger.push(Registry(vehicleAddress=msg.sender, lane=laneId, time=now, registryEvent=RegistryEvent.ENTERED_CROSSING, permission=permissionOfAddress[msg.sender]));

        // take permission and mark lane as occupied
        ownerHasPermission[msg.sender] = false;
        permissionOfAddress[msg.sender] = null;
        lanes[laneId].state = State.OCCUPIED;

        ledger.push(Registry(vehicleAddress=msg.sender, lane=laneId, time=now, registryEvent=RegistryEvent.PERMISSION_REMOVED, permission=permissionOfAddress[msg.sender]));

        emit LaneOccupied(laneId);
    }

    // infrastructure signals car left crossing
    function carLeave(uint _laneId, address _vehicleAddress) external onlyOwner {
        if (lanes[_laneId].state == State.LOCKED) {
            lanes[_laneId].state == State.FREE_TO_CROSS;
        } else if (lanes[_laneId].state == State.OCCUPIED_AND_LOCKING) {
            lanes[_laneId].state == State.LOCKED;
            _checkTrainCanPass();
        }

        lanes[_laneId].capacity--;
        laneOfCar[_vehicleAddress] = null;

        lastInfrastructureUpdate = now;

        emit LaneFree(_laneId);
    }
}
