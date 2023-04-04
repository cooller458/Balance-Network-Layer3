pragma solidity ^0.8.0;

enum ValueType {
    I32,
    I64,
    F32,
    F64,
    REF_NULL,
    FUNC_REF,
    INTERNAL_REF
}

struct Value {
    ValueType valueType;
    uint256 contents;
}

library ValueLib{
    function hash(Value memory val) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("Value:", val.valueType, val.contents));
    }
    function maxValueType() internal pure returns (ValueType) {
        return ValueType.INTERNAL_REF;
    }
    function assumeI32(Value memory val) internal pure returns (uint32) {
        uint256 uintval = uint256(val.contents);
        require(val.valueType == ValueType.I32, "Value is not an I32");
        require(uintval < ( 1 << 32), "BAD_32");
        return uint32(uintval);
    }
    function newRefNull() internal pure returns (Value memory) {
        return Value({valueType: ValueType.REF_NULL, contents: 0});
    }
    function newI32(uint32 val) internal pure returns (Value memory) {
        return Value({valueType: ValueType.I32, contents: uint256(x)});
    }
        function newI64(uint64 x) internal pure returns (Value memory) {
        return Value({valueType: ValueType.I64, contents: uint256(x)});
    }

    function newBoolean(bool x) internal pure returns (Value memory) {
        if (x) {
            return newI32(uint32(1));
        } else {
            return newI32(uint32(0));
        }
    }

}