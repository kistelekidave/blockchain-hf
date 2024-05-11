pragma solidity >=0.5.0 <0.6.0;

contract RailroadCrossing {

    event NewZombie(uint zombieId, string name, uint dna);

    // States of a train crossing
    enum State { FREE_TO_CROSS, LOCKED, OCCUPIED, OCCUPIED_AND_LOCKING };
    // FREE_TO_CROSS: nincs vonat es auto a keresztezodesben es vonat nem is erkezik
    // LOCKED: van vagy erkezik vonat es nincs auto a keresztezodesben
    // OCCUPIED: auto van a keresztezodesben nem jon vonat
    // OCCUPIED_AND_LOCKING: auto van a keresztezodesben es jon vonat, vagy nem erkezik frissites -> nem johet tobb auto

    uint public lastInfrastructureUpdate;
    uint public validityTime;

    struct CrossingToken {
        uint id;
        uint expirationDate;
    }

    struct Lane {
        State state;
        CrossingToken[] public tokens;
        uint maxCapacity;
    }

    Lane[] public lanes;
    uint public lanesNumber;

    // Constructor
    constructor(uint _lanesNumber, uint _maxCapacityByLane, uint _validityTime) {
        validityTime = _validityTime;
        lanesNumber = _lanesNumber;
        for (uint i = 0; i < _lanesNumber; i++) {
            lanes.push(Lane(state=State.LOCKED, maxCapacity=_maxCapacityByLane)); //initial state: LOCKED
        }
    }

    // Railroad infrastructure signals to set State
    function setLaneState(uint _laneId, State _state) public {
        lanes[_laneId].state = _state;
    }

    // Car signals to create token
    function createToken(uint _laneId) public {
        require(lanes[_laneId].state == State.FREE_TO_CROSS);
        lanes[_laneId].tokens.push(CrossingToken(id=, expirationDate=));
    }

    // Car uses token to cross
    function useToken(uint _laneId, uint _tokenId) public {
        lanes[_laneId].tokens[_tokenId].expirationDate = block.timestamp + 3600;
    }


    // function _createZombie(string memory _name, uint _dna) private {
    //     uint id = zombies.push(Zombie(_name, _dna)) - 1;
    //     zombieToOwner[id] = msg.sender;
    //     ownerZombieCount[msg.sender]++;
    //     emit NewZombie(id, _name, _dna);
    // }

    // function _generateRandomDna(string memory _str) private view returns (uint) {
    //     uint rand = uint(keccak256(abi.encodePacked(_str)));
    //     return rand % dnaModulus;
    // }

    // function createRandomZombie(string memory _name) public {
    //     require(ownerZombieCount[msg.sender] == 0);
    //     uint randDna = _generateRandomDna(_name);
    //     _createZombie(_name, randDna);
    // }
}
