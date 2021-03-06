//
//  IntOperators.swift
//  Atem
//
//  Created by Damiaan on 11-11-16.
//
//

import Foundation

extension UInt8 {
	var firstBit: Bool {return self & 1 == 1}
}

extension FixedWidthInteger {
	init(from slice: ArraySlice<UInt8>) {
		self.init(bigEndian: slice.withUnsafeBufferPointer{
			$0.baseAddress!.withMemoryRebound(to: Self.self, capacity: 1) {$0.pointee}
		})
	}

	var bytes: [UInt8] {
		let byteCount = bitWidth >> 3
		return [UInt8](unsafeUninitializedCapacity: byteCount) { (pointer, count) in
			UnsafeMutableRawPointer(pointer.baseAddress!).bindMemory(to: Self.self, capacity: 1).pointee = bigEndian
			count = byteCount
		}
	}
}

extension ArraySlice {
	subscript(relative index: Index) -> Element {
		return self[startIndex + index]
	}
	
	subscript<R: AdvancableRange>(relative range: R) -> SubSequence where R.Bound == Index {
		return self[range.advanced(by: startIndex)]
	}
}

protocol AdvancableRange: RangeExpression where Bound: Strideable {
	func advanced(by stride: Bound.Stride) -> Self
}

extension CountableRange: AdvancableRange {
	func advanced(by stride: Bound.Stride) -> CountableRange<Bound> {
		return CountableRange(uncheckedBounds: (lower: lowerBound.advanced(by: stride), upper: upperBound.advanced(by: stride)))
	}
}

extension CountablePartialRangeFrom: AdvancableRange {
	func advanced(by stride: Bound.Stride) -> CountablePartialRangeFrom<Bound> {
		return CountablePartialRangeFrom(lowerBound.advanced(by: stride))
	}
}

extension UnsafeMutableBufferPointer where Element == UInt8 {
	func write<I: FixedWidthInteger>(_ number: I, at offset: Int) {
        UnsafeMutableRawPointer(baseAddress!.advanced(by: offset)).bindMemory(to: I.self, capacity: 1).pointee = number
	}
}
