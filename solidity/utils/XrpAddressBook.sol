pragma solidity 0.5.0;

interface OrbitHub {
    function getBridgeMig(string calldata, bytes32) external view returns (address);
}

interface MultiSig {
    function validate(address validator, bytes32 hash, uint8 v, bytes32 r, bytes32 s) external returns (bool);
    function isValidatedHash(bytes32 hash) external view returns (bool);
}

contract XrpAddressBook {
    mapping(bytes32 => mapping(bytes32 => mapping(bytes32=> uint))) public tags;
    mapping(uint => string) public chains;
    mapping(uint => bytes) public addrs;
    mapping(uint => bytes) public datas;

    address public owner; // gov hub mig ?
    address public hub;
    bytes32 public id;
    uint public count = 1100002111;
    address payable public implementation;

    constructor(address _hub, bytes32 _id, address payable _implementation) public {
        owner = msg.sender;
        hub = _hub;
        id = _id;
        implementation = _implementation;
    }

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    function _setImplementation(address payable _newImp) public onlyOwner {
        require(implementation != _newImp);
        implementation = _newImp;
    }

    function () payable external {
        address impl = implementation;
        require(impl != address(0));
        assembly {
            let ptr := mload(0x40)
            calldatacopy(ptr, 0, calldatasize)
            let result := delegatecall(gas, impl, ptr, calldatasize, 0, 0)
            let size := returndatasize
            returndatacopy(ptr, 0, size)

            switch result
            case 0 { revert(ptr, size) }
            default { return(ptr, size) }
        }
    }
}

contract XrpAddressBookImpl is XrpAddressBook {
    event Relay(string toChain, bytes toAddr, bytes data, bytes32 hash);
    event Set(string toChain, bytes toAddr, bytes data, uint tag, bytes32 hash);

    constructor() public XrpAddressBook(address(0), 0, address(0)) {}

    function getVersion() public pure returns (string memory) {
        return "20210330a";
    }

    function transferOwnership(address _owner) public onlyOwner {
        owner = _owner;
    }

    function setHubContract(address _hub) public onlyOwner {
        hub = _hub;
    }

    function setId(bytes32 _id) public onlyOwner {
        id = _id;
    }

    function relay(string memory toChain, bytes memory toAddr, bytes memory data) public {
        require(OrbitHub(hub).getBridgeMig(toChain, id) != address(0));

        bytes32 toChainHash = generate(bytes(toChain));
        bytes32 toAddrHash = generate(toAddr);
        bytes32 dataHash = generate(data);
        require(tags[toChainHash][toAddrHash][dataHash] == 0);

        emit Relay(toChain, toAddr, data, sha256(abi.encodePacked(toChain, toAddr, data)));
    }

    function set(string memory toChain, bytes memory toAddr, bytes memory data, address validator, uint8 v, bytes32 r, bytes32 s) public {
        // hub 에서 gov 가 연결된 toChain만 tag 발급해준다.
        require(OrbitHub(hub).getBridgeMig(toChain, id) != address(0));

        bytes32 toChainHash = generate(bytes(toChain));
        bytes32 toAddrHash = generate(toAddr);
        bytes32 dataHash = generate(data);
        require(tags[toChainHash][toAddrHash][dataHash] == 0);

        // isConfirmed ?
        bytes32 hash = sha256(abi.encodePacked(toChain, toAddr, data));

        bool major;
        address mig = OrbitHub(hub).getBridgeMig("XRP", id); // XRP Bridge Mig 에 서명값 넣어둔다
        if(validator != address(0))
            major = MultiSig(mig).validate(validator, hash, v, r, s);
        else
            major = MultiSig(mig).isValidatedHash(hash);

        if (major) {
            count = count + 1;
            tags[toChainHash][toAddrHash][dataHash] = count;
            chains[count] = toChain;
            addrs[count] = toAddr;
            datas[count] = data;

            emit Set(toChain, toAddr, data, count, hash);
        }
    }

    function get(uint tag) public view returns (string memory toChain, bytes memory toAddr, bytes memory data){
        toChain = chains[tag];
        toAddr = addrs[tag];
        data = datas[tag];
    }

    function get(string memory toChain, bytes memory toAddr, bytes memory data) public view returns (uint tag) {
        tag = tags[generate(bytes(toChain))][generate(toAddr)][generate(data)];
    }

    function generate(bytes memory ctx) public view returns(bytes32){
        return sha256(abi.encodePacked(address(this), ctx));
    }
}
