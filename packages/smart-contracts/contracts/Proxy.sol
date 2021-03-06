// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.7.0;
pragma experimental ABIEncoderV2;

import "./Auth.sol";
import "./Guard.sol";

// Proxy
// Allows code execution using a persistant identity This can be very
// useful to execute a sequence of atomic actions. Since the owner of
// the proxy can be changed, this allows for dynamic ownership models
// i.e. a multisig
contract Proxy is Auth {
    constructor() public {}

    receive() external payable {}

    // Nested calls without prematurely forbidding arbitrary callbacks
    mapping(address => uint256) entries;

    function execute(address payable _target, bytes memory _data)
        public
        payable
        auth
        returns (bytes memory response)
    {
        require(_target != address(0), "proxy-target-address-required");

        Guard g = Guard(authority);

        // How nested is this?
        // For example, flashloan, I would like to be able
        // to nest flashloan of ETH, DAI, and SNX from Aave
        // Permits contract to perform some arbitrary callback
        if (entries[_target] == 0) {
            g.permit(bytes32(bytes20(_target)), g.ANY(), g.ANY());
        }
        entries[_target] = entries[_target] + 1;

        // call contract in current context
        assembly {
            let succeeded := delegatecall(
                sub(gas(), 5000),
                _target,
                add(_data, 0x20),
                mload(_data),
                0,
                0
            )
            let size := returndatasize()

            response := mload(0x40)
            mstore(
                0x40,
                add(response, and(add(add(size, 0x20), 0x1f), not(0x1f)))
            )
            mstore(response, size)
            returndatacopy(add(response, 0x20), 0, size)

            switch iszero(succeeded)
                case 1 {
                    // throw if delegatecall failed
                    revert(add(response, 0x20), size)
                }
        }

        // Forbids contract to perform arbitrary callback
        entries[_target] = entries[_target] - 1;
        if (entries[_target] == 0) {
            g.forbid(bytes32(bytes20(_target)), g.ANY(), g.ANY());
        }
    }

    function executes(
        address payable[] memory _targets,
        bytes[] memory _data,
        uint256[] memory _msgValues
    ) public payable auth returns (bytes memory response) {
        require(
            _targets.length == _data.length &&
                _data.length == _msgValues.length,
            "proxy-target-data-invalid-length"
        );

        // Only return last response
        for (uint256 i = 0; i < _targets.length; i++) {
            // Sometimes we want to send specific number of ETH
            // on a specific transaction. This allows us to do that
            response = Proxy(address(this)).execute{value: _msgValues[i]}(
                _targets[i],
                _data[i]
            );
        }
    }
}

// ProxyFactory
// This factory deploys new proxy instances through build()
// Deployed proxy addresses are also registered into a mapping of creator => proxy
contract ProxyFactory {
    event Created(address indexed sender, address indexed owner, address proxy);
    mapping(address => address) public proxies;

    GuardFactory public guardFactory;

    constructor() public {
        guardFactory = new GuardFactory();
    }

    function build() public returns (address payable proxy) {
        proxy = build(msg.sender);
    }

    function build(address owner) public returns (address payable proxy) {
        proxy = address(new Proxy());

        address guard = guardFactory.newGuard(proxy);

        Proxy(proxy).setAuthority(guard);
        Proxy(proxy).setOwner(owner);

        proxies[owner] = address(proxy);

        emit Created(msg.sender, owner, address(proxy));
    }
}
