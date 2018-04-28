pragma solidity ^0.4.22;

library SafeMath {
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        assert(c / a == b);
        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        // assert(b > 0); // Solidity automatically throws when dividing by 0
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold
        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        assert(b <= a);
        return a - b;
    }

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        assert(c >= a);
        return c;
    }
}

contract ERC223 {
    function name() public view returns (string);
    function symbol() public view returns (string);
    function decimals() public view returns (uint8);
    function totalSupply() public view returns (uint256);

    function balanceOf(address _owner) public view returns (uint256);
    function transfer(address _to, uint256 _value) public returns (bool);
    function transfer(address _to, uint256 _value, bytes _data) public returns (bool); //ERC223
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool);
    function approve(address _spender, uint256 _value) public returns (bool);
    function allowance(address _owner, address _spender) public view returns (uint256);

    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Transfer(address indexed _from, address indexed _to, uint256 indexed _value, bytes _data);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);
}

contract ERC223ReceivingContract {
    function tokenFallback(address _from, uint _value, bytes _data) public;
}

contract ERCAddressFrozenFund is ERC223{

    using SafeMath for uint256;

    struct LockedWallet {
        address owner; // the owner of the locked wallet, he/she must secure the private key
        uint256 amount; //
        uint256 start; // timestamp when "lock" function is executed
        uint256 duration; // duration period in seconds. if we want to lock an amount for
        uint256 release;  // release = start+duration
        // "start" and "duration" is for bookkeeping purpose only. Only "release" will be actually checked once unlock function is called
    }


    address public owner;

    uint256 _lockedSupply;

    mapping (address => LockedWallet) addressFrozenFund; //address -> (deadline, amount),freeze fund of an address its so that no token can be transferred out until deadline

    function mintToken(address _owner, uint256 amount) internal;
    function burnToken(address _owner, uint256 amount) internal;

    event LockBalance(address indexed addressOwner, uint256 releasetime, uint256 amount);
    event LockSubBalance(address indexed addressOwner, uint256 index, uint256 releasetime, uint256 amount);
    event UnlockBalance(address indexed addressOwner, uint256 releasetime, uint256 amount);
    event UnlockSubBalance(address indexed addressOwner, uint256 index, uint256 releasetime, uint256 amount);

    function lockedSupply() public view returns (uint256) {
        return _lockedSupply;
    }

    function releaseTimeOf(address _owner) public view returns (uint256 releaseTime) {
        return addressFrozenFund[_owner].release;
    }

    function lockedBalanceOf(address _owner) public view returns (uint256 lockedBalance) {
        return addressFrozenFund[_owner].amount;
    }

    function lockBalance(uint256 duration, uint256 amount) public returns (bool) {

        address _owner = msg.sender;

        require(address(0) != _owner && amount > 0 && duration > 0 && this.balanceOf(_owner) >= amount);
        require(addressFrozenFund[_owner].release <= now && addressFrozenFund[_owner].amount == 0);

        addressFrozenFund[_owner].start = now;
        addressFrozenFund[_owner].duration = duration;
        addressFrozenFund[_owner].release = addressFrozenFund[_owner].start.add(duration);
        addressFrozenFund[_owner].amount = amount;
        burnToken(_owner, amount);
        _lockedSupply = _lockedSupply.add(lockedBalanceOf(_owner));

        emit LockBalance(_owner, addressFrozenFund[_owner].release, amount);
        return true;
    }
    function releaseLockedBalance() public returns (bool) {

        address _owner = msg.sender;

        require(address(0) != _owner && lockedBalanceOf(_owner) > 0 && releaseTimeOf(_owner) <= now);
        mintToken(_owner, lockedBalanceOf(_owner));
        _lockedSupply = _lockedSupply.sub(lockedBalanceOf(_owner));

        emit UnlockBalance(_owner, addressFrozenFund[_owner].release, lockedBalanceOf(_owner));

        delete addressFrozenFund[_owner];
        return true;
    }
}

contract Token is ERCAddressFrozenFund {
    using SafeMath for uint256;

    string public name = "__TOKEN_NAME";
    string public symbol = "__TOKEN_SYMBOL";
    uint8 public decimals = 18;
    uint256 public totalSupply = 10000;
    address public owner;

    mapping (address => uint256) internal balances;
    mapping (address => mapping (address => uint256)) internal allowed;

    constructor() public {
        owner = msg.sender;
        balances[owner] = totalSupply;
    }
    function() public {
        //if ether is sent to this address, send it back.
        revert();
    }

    function balanceOf(address _owner) public view returns (uint256) {
        return balances[_owner];
    }

    function transfer(address _to, uint256 _value) public returns (bool) {
        require(_to != address(0));
        require(_value <= balances[msg.sender]);

        balances[msg.sender] = balances[msg.sender].sub(_value);
        balances[_to] = balances[_to].add(_value);

        if (isContract(_to)) {
            bytes memory empty;
            ERC223ReceivingContract receiver = ERC223ReceivingContract(_to);
            receiver.tokenFallback(msg.sender, _value, empty);
        }

        emit Transfer(msg.sender, _to, _value);

        return true;
    }

    function transfer(address _to, uint256 _value, bytes _data) public returns (bool) {
        require(_to != address(0));
        require(_value <= balances[msg.sender]);

        balances[msg.sender] = balances[msg.sender].sub(_value);
        balances[_to] = balances[_to].add(_value);

        if (isContract(_to)) {
            ERC223ReceivingContract receiver = ERC223ReceivingContract(_to);
            receiver.tokenFallback(msg.sender, _value, _data);
        }

        emit Transfer(msg.sender, _to, _value, _data);

        return true;
    }

    function approve(address _spender, uint256 _value) public returns (bool) {
        allowed[msg.sender][_spender] = _value;
        
        emit Approval(msg.sender, _spender, _value);

        return true;
    }

    function increaseApproval(address _spender, uint256 _value) public returns (bool) {
        allowed[msg.sender][_spender] = allowed[msg.sender][_spender].add(_value);

        emit Approval(msg.sender, _spender, allowed[msg.sender][_spender]);

        return true;
    }

    function decreaseApproval(address _spender, uint256 _value) public returns (bool) {
        if (_value >= allowed[msg.sender][_spender]) {
            allowed[msg.sender][_spender] = 0;
        } else {
            allowed[msg.sender][_spender] = allowed[msg.sender][_spender].sub(_value);
        }

        emit Approval(msg.sender, _spender, allowed[msg.sender][_spender]);

        return true;
    }

    function allowance(address _owner, address _spender) public view returns (uint256) {
        return allowed[_owner][_spender];
    }

    function transferFrom(address _from, address _to, uint256 _value) public returns (bool) {
        require(_to != address(0));
        require(_value <= allowed[_from][msg.sender] && _value <= balances[_from]);

        balances[_from] = balances[_from].sub(_value);
        allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);
        balances[_to] = balances[_to].add(_value);

        if (isContract(_to)) {
            ERC223ReceivingContract receiver = ERC223ReceivingContract(_to);
            bytes memory empty;
            receiver.tokenFallback(msg.sender, _value, empty);
        }

        emit Transfer(_from, _to, _value);

        return true;
    }

    function isContract(address _addr) private view returns (bool is_contract) {
        uint length;
        assembly {
        //retrieve the size of the code on target address, this needs assembly
            length := extcodesize(_addr)
        }
        return (length>0);
    }
}
