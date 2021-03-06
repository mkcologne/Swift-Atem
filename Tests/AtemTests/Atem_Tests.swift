import XCTest
@testable import Atem

import NIO
import Dispatch

class Atem_Tests: XCTestCase {
	
	func testConnectionHandlers() throws {
		let controller = EmbeddedChannel()
		let switcher = EmbeddedChannel()
		let cEventLoop = controller.eventLoop as! EmbeddedEventLoop
		let sEventLoop = switcher.eventLoop as! EmbeddedEventLoop
		defer {
			let _ = try! controller.finish()
			let _ = try! switcher.finish()
		}

		func packet(from data: IOData?) -> (content: Packet, raw: [UInt8])? {
			if case .some(.byteBuffer(var msg)) = data {
				let bytes = msg.readBytes(length: msg.readableBytes)!
				return (Packet(bytes: bytes), bytes)
			} else {
				return nil
			}
		}

		func send(bytes: [UInt8], to channel: EmbeddedChannel) {
			var buffer = switcher.allocator.buffer(capacity: bytes.count)
			buffer.writeBytes(bytes)
			try! channel.writeInbound(buffer)
		}

		try! controller.pipeline.addHandler(IODataWrapper()).wait()
		try! controller.pipeline.addHandler(EnvelopeWrapper()).wait()
		try! controller.pipeline.addHandler(
			ControllerHandler(
				address: try! .init(ipAddress: "10.1.0.100", port: 9910),
				messageHandler: PureMessageHandler()
			)
		).wait()


		try! switcher.pipeline.addHandler(IODataWrapper()).wait()
		try! switcher.pipeline.addHandler(EnvelopeWrapper()).wait()
		try! switcher.pipeline.addHandler(SwitcherHandler(handler: ContextualMessageHandler())).wait()

		controller.pipeline.fireChannelActive()
		switcher.pipeline.fireChannelActive()

		cEventLoop.advanceTime(by: .milliseconds(10))
		sEventLoop.advanceTime(by: .milliseconds(10))

		XCTAssertNil(try controller.readOutbound())
		cEventLoop.advanceTime(by: .milliseconds(20))

		guard let 📦1 = packet(from: try controller.readOutbound()) else {
			XCTFail("No writes")
			return
		}
		XCTAssertNil(try controller.readOutbound())
		XCTAssertTrue(📦1.content.isConnect)
		XCTAssertFalse(📦1.content.isRepeated)

		send(bytes: 📦1.raw, to: switcher)

		guard let 📦2 = packet(from: try switcher.readOutbound()) else {
			XCTFail("No writes")
			return
		}
		XCTAssertNil(try switcher.readOutbound())
		XCTAssertTrue(📦2.content.isConnect)
		XCTAssertEqual(📦2.raw[12..<14], [2, 0])

		send(bytes: 📦2.raw, to: controller)

		cEventLoop.advanceTime(by: .milliseconds(20))
		guard let 📦3 = packet(from: try controller.readOutbound()) else {
			XCTFail("No writes")
			return
		}
		XCTAssertEqual(📦3.content.acknowledgement, 0)

		send(bytes: 📦3.raw, to: switcher)
		sEventLoop.advanceTime(by: .milliseconds(20))
		var initialBytesRead = 0
		let initialBytesToRead = initialMessages.reduce(0) { count, message in count + message.count }
		var number = UInt16(1)
		while initialBytesRead < initialBytesToRead {
			guard let 📦 = packet(from: try switcher.readOutbound()) else {
				XCTFail("\(initialBytesRead) instead of \(initialBytesToRead) initial state message bytes")
				return
			}
			for message in 📦.content.messages {
				initialBytesRead += message.count + 4
			}
			XCTAssertEqual(📦.content.number, number)
			number += 1
			XCTAssertFalse(📦.content.isRepeated)
		}

	}
		
	func testInPrMessages() {
		let initialInPr: [UInt8] = [0x00, 0x2c, 0x17, 0x60, 0x49, 0x6e, 0x50, 0x72, 0x00, 0x0f, 0x43, 0x61, 0x6d, 0x65, 0x72, 0x61, 0x20, 0x31, 0x35, 0x00, 0x41, 0x54, 0x45, 0x4d, 0x20, 0x32, 0x20, 0x4d, 0x2f, 0x45, 0x43, 0x6d, 0x31, 0x35, 0x01, 0x75, 0x00, 0x01, 0x00, 0x01, 0x00, 0x20, 0x1f, 0x03, 0x00, 0x2c, 0x69, 0x6f, 0x49, 0x6e, 0x50, 0x72, 0x00, 0x10, 0x43, 0x61, 0x6d, 0x65, 0x72, 0x61, 0x20, 0x31, 0x36, 0x00, 0x00, 0x20, 0x00, 0x00, 0x5f, 0x74, 0x6f, 0x70, 0x02, 0x2f, 0x43, 0x6d, 0x31, 0x36, 0x01, 0x04, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0x1f, 0x03, 0x00, 0x2c, 0x01, 0x01, 0x49, 0x6e, 0x50, 0x72, 0x00, 0x11, 0x43, 0x61, 0x6d, 0x65, 0x72, 0x61, 0x20, 0x31, 0x37, 0x00, 0x00, 0x0c, 0x15, 0x60, 0x5f, 0x4d, 0x65, 0x43, 0x01, 0x02, 0x43, 0x6d, 0x31, 0x37, 0x01, 0x60, 0x00, 0x01, 0x00, 0x01, 0x00, 0x02, 0x1f, 0x03, 0x00, 0x2c, 0xe7, 0x60, 0x49, 0x6e, 0x50, 0x72, 0x00, 0x12, 0x43, 0x61, 0x6d, 0x65, 0x72, 0x61, 0x20, 0x31, 0x38, 0x00, 0x5f, 0x53, 0x53, 0x43, 0x04, 0x00, 0x00, 0x00, 0x00, 0x0c, 0x43, 0x6d, 0x31, 0x38, 0x01, 0x43, 0x00, 0x01, 0x00, 0x01, 0x00, 0xe4, 0x1f, 0x03, 0x00, 0x2c, 0x4d, 0x43, 0x49, 0x6e, 0x50, 0x72, 0x00, 0x13, 0x43, 0x61, 0x6d, 0x65, 0x72, 0x61, 0x20, 0x31, 0x39, 0x00, 0x01, 0xc1, 0xea, 0x60, 0x00, 0x00, 0x00, 0x40, 0x00, 0x00, 0x43, 0x6d, 0x31, 0x39, 0x01, 0x60, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0x1f, 0x03, 0x00, 0x2c, 0x15, 0x60, 0x49, 0x6e, 0x50, 0x72, 0x00, 0x14, 0x43, 0x61, 0x6d, 0x65, 0x72, 0x61, 0x20, 0x32, 0x30, 0x00, 0x00, 0x00, 0x00, 0x10, 0x05, 0xae, 0x15, 0x60, 0x00, 0x00, 0x43, 0x6d, 0x32, 0x30, 0x01, 0x20, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0x1f, 0x03, 0x00, 0x2c, 0x00, 0x40, 0x49, 0x6e, 0x50, 0x72, 0x03, 0xe8, 0x43, 0x6f, 0x6c, 0x6f, 0x72, 0x20, 0x42, 0x61, 0x72, 0x73, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x00, 0x09, 0x47, 0x42, 0x61, 0x72, 0x73, 0x01, 0x00, 0x01, 0x00, 0x01, 0x00, 0x02, 0x00, 0x1f, 0x03, 0x00, 0x2c, 0x00, 0x40, 0x49, 0x6e, 0x50, 0x72, 0x07, 0xd1, 0x43, 0x6f, 0x6c, 0x6f, 0x72, 0x20, 0x31, 0x00, 0x08, 0x00, 0x0c, 0xe6, 0xe9, 0x60, 0x00, 0x00, 0x00, 0x40, 0x00, 0x00, 0x43, 0x6f, 0x6c, 0x31, 0x01, 0x60, 0x01, 0x00, 0x01, 0x00, 0x03, 0x00, 0x0f, 0x03, 0x00, 0x2c, 0x65, 0x60, 0x49, 0x6e, 0x50, 0x72, 0x07, 0xd2, 0x43, 0x6f, 0x6c, 0x6f, 0x72, 0x20, 0x32, 0x00, 0x02, 0x00, 0x00, 0x00, 0x02, 0x00, 0x10, 0x47, 0x65, 0x60, 0x00, 0x00, 0x43, 0x6f, 0x6c, 0x32, 0x01, 0x40, 0x01, 0x00, 0x01, 0x00, 0x03, 0x00, 0x0f, 0x03, 0x00, 0x2c, 0x00, 0x80, 0x49, 0x6e, 0x50, 0x72, 0x0b, 0xc2, 0x4d, 0x65, 0x64, 0x69, 0x61, 0x20, 0x50, 0x6c, 0x61, 0x79, 0x65, 0x72, 0x20, 0x31, 0x00, 0x01, 0x00, 0x23, 0x10, 0x11, 0x4d, 0x50, 0x31, 0x00, 0x01, 0x17, 0x01, 0x00, 0x01, 0x00, 0x04, 0x1d, 0x1f, 0x03, 0x00, 0x2c, 0x01, 0x02, 0x49, 0x6e, 0x50, 0x72, 0x0b, 0xc3, 0x4d, 0x65, 0x64, 0x69, 0x61, 0x20, 0x50, 0x6c, 0x61, 0x79, 0x65, 0x72, 0x20, 0x31, 0x20, 0x4b, 0x65, 0x79, 0x00, 0xb5, 0x4d, 0x50, 0x31, 0x4b, 0x01, 0x60, 0x01, 0x00, 0x01, 0x00, 0x05, 0xb5, 0x1f, 0x03, 0x00, 0x2c, 0x17, 0x60, 0x49, 0x6e, 0x50, 0x72, 0x0b, 0xcc, 0x4d, 0x65, 0x64, 0x69, 0x61, 0x20, 0x50, 0x6c, 0x61, 0x79, 0x65, 0x72, 0x20, 0x32, 0x00, 0x0c, 0x13, 0x60, 0x44, 0x48, 0x4d, 0x50, 0x32, 0x00, 0x01, 0x60, 0x01, 0x00, 0x01, 0x00, 0x04, 0x48, 0x1f, 0x03, 0x00, 0x2c, 0x00, 0x00, 0x49, 0x6e, 0x50, 0x72, 0x0b, 0xcd, 0x4d, 0x65, 0x64, 0x69, 0x61, 0x20, 0x50, 0x6c, 0x61, 0x79, 0x65, 0x72, 0x20, 0x32, 0x20, 0x4b, 0x65, 0x79, 0x00, 0x0c, 0x4d, 0x50, 0x32, 0x4b, 0x01, 0x6d, 0x01, 0x00, 0x01, 0x00, 0x05, 0x0c, 0x1f, 0x03, 0x00, 0x2c, 0x56, 0x6d, 0x49, 0x6e, 0x50, 0x72, 0x17, 0x70, 0x50, 0x49, 0x50, 0x00, 0x56, 0x6d, 0x08, 0x08, 0xe9, 0x60, 0x00, 0x0c, 0xe9, 0x60, 0x44, 0x48, 0x56, 0x6d, 0x09, 0x09, 0x50, 0x49, 0x50, 0x00, 0x00, 0x60, 0x01, 0x00, 0x01, 0x00, 0x06, 0x0a, 0x1b, 0x03, 0x00, 0x2c, 0x00, 0x00, 0x49, 0x6e, 0x50, 0x72, 0x0f, 0xaa, 0x4d, 0x45, 0x20, 0x31, 0x20, 0x4b, 0x65, 0x79, 0x20, 0x31, 0x20, 0x4d, 0x61, 0x73, 0x6b, 0x00, 0x19, 0x60, 0x44, 0x48, 0x4d, 0x31, 0x4b, 0x31, 0x01, 0x00, 0x01, 0x00, 0x01, 0x00, 0x82, 0x48, 0x03, 0x00, 0x00, 0x2c, 0x3b, 0x60, 0x49, 0x6e, 0x50, 0x72, 0x0f, 0xb4, 0x4d, 0x45, 0x20, 0x31, 0x20, 0x4b, 0x65, 0x79, 0x20, 0x32, 0x20, 0x4d, 0x61, 0x73, 0x6b, 0x00, 0x00, 0x00, 0x00, 0x0c, 0x4d, 0x31, 0x4b, 0x32, 0x01, 0x6d, 0x01, 0x00, 0x01, 0x00, 0x82, 0x0c, 0x03, 0x00, 0x00, 0x2c, 0x73, 0x6c, 0x49, 0x6e, 0x50, 0x72, 0x0f, 0xbe, 0x4d, 0x45, 0x20, 0x32, 0x20, 0x4b, 0x65, 0x79, 0x20, 0x31, 0x20, 0x4d, 0x61, 0x73, 0x6b, 0x00, 0x20, 0x20, 0x21, 0x21, 0x4d, 0x32, 0x4b, 0x31, 0x01, 0x00, 0x01, 0x00, 0x01, 0x00, 0x82, 0x00, 0x03, 0x00, 0x00, 0x2c, 0x01, 0x00, 0x49, 0x6e, 0x50, 0x72, 0x0f, 0xc8, 0x4d, 0x45, 0x20, 0x32, 0x20, 0x4b, 0x65, 0x79, 0x20, 0x32, 0x20, 0x4d, 0x61, 0x73, 0x6b, 0x00, 0x53, 0x00, 0x5c, 0x00, 0x4d, 0x32, 0x4b, 0x32, 0x01, 0x60, 0x01, 0x00, 0x01, 0x00, 0x82, 0x52, 0x03, 0x00, 0x00, 0x2c, 0x00, 0x01, 0x49, 0x6e, 0x50, 0x72, 0x13, 0x92, 0x44, 0x53, 0x4b, 0x20, 0x31, 0x20, 0x4d, 0x61, 0x73, 0x6b, 0x00, 0x48, 0x52, 0x49, 0x53, 0x00, 0x00, 0x00, 0x01, 0x00, 0x44, 0x4b, 0x31, 0x4d, 0x01, 0x8f, 0x01, 0x00, 0x01, 0x00, 0x82, 0x49, 0x03, 0x00, 0x00, 0x2c, 0x00, 0x01, 0x49, 0x6e, 0x50, 0x72, 0x13, 0x9c, 0x44, 0x53, 0x4b, 0x20, 0x32, 0x20, 0x4d, 0x61, 0x73, 0x6b, 0x00, 0x4c, 0x49, 0x44, 0x45, 0x52, 0x20, 0x00, 0x21, 0x21, 0x44, 0x4b, 0x32, 0x4d, 0x01, 0x00, 0x01, 0x00, 0x01, 0x00, 0x82, 0x52, 0x03, 0x00, 0x00, 0x2c, 0x00, 0x01, 0x49, 0x6e, 0x50, 0x72, 0x27, 0x1a, 0x4d, 0x45, 0x20, 0x31, 0x20, 0x50, 0x47, 0x4d, 0x00, 0x20, 0x4e, 0x4f, 0x4e, 0x45, 0x00, 0x31, 0x31, 0x31, 0x58, 0xb7, 0x50, 0x67, 0x6d, 0x31, 0x01, 0x60, 0x01, 0x00, 0x01, 0x00, 0x80, 0x45, 0x03, 0x00, 0x00, 0x2c, 0x00, 0x01, 0x49, 0x6e, 0x50, 0x72, 0x27, 0x1b, 0x4d, 0x45, 0x20, 0x31, 0x20, 0x50, 0x56, 0x57, 0x00, 0x20, 0x44, 0x52, 0x55, 0x4d, 0x53, 0x00, 0x65, 0x60, 0xf1, 0x02, 0x50, 0x76, 0x77, 0x31, 0x01, 0x00, 0x01, 0x00, 0x01, 0x00, 0x80, 0x4d, 0x03, 0x00, 0x00, 0x2c, 0x00, 0x01, 0x49, 0x6e, 0x50, 0x72, 0x27, 0x24, 0x4d, 0x45, 0x20, 0x32, 0x20, 0x50, 0x47, 0x4d, 0x00, 0x20, 0x57, 0x49, 0x44, 0x45, 0x00, 0x00, 0x00, 0x00, 0x54, 0x4a, 0x50, 0x67, 0x6d, 0x32, 0x01, 0x00, 0x01, 0x00, 0x01, 0x00, 0x80, 0x45, 0x0b, 0x01, 0x00, 0x2c, 0x00, 0x01, 0x49, 0x6e, 0x50, 0x72, 0x27, 0x25, 0x4d, 0x45, 0x20, 0x32, 0x20, 0x50, 0x56, 0x57, 0x00, 0x20, 0x69, 0x4d, 0x41, 0x43, 0x00, 0x00, 0x00, 0x00, 0x10, 0x4b, 0x50, 0x76, 0x77, 0x32, 0x01, 0x00, 0x01, 0x00, 0x01, 0x00, 0x80, 0x43, 0x0b, 0x01, 0x00, 0x2c, 0x00, 0x01, 0x49, 0x6e, 0x50, 0x72, 0x1b, 0x59, 0x43, 0x6c, 0x65, 0x61, 0x6e, 0x20, 0x46, 0x65, 0x65, 0x64, 0x20, 0x31, 0x00, 0x4e, 0x4b, 0x00, 0x00, 0x60, 0x00, 0x00, 0x43, 0x66, 0x64, 0x31, 0x01, 0x00, 0x01, 0x00, 0x01, 0x00, 0x80, 0x00, 0x03, 0x00, 0x00, 0x2c, 0x00, 0x01, 0x49, 0x6e, 0x50, 0x72, 0x1b, 0x5a, 0x43, 0x6c, 0x65, 0x61, 0x6e, 0x20, 0x46, 0x65, 0x65, 0x64, 0x20, 0x32, 0x00, 0x45, 0x53, 0x00, 0x3c, 0x60, 0x01, 0x00, 0x43, 0x66, 0x64, 0x32, 0x01, 0x60, 0x01, 0x00, 0x01, 0x00, 0x80, 0x45, 0x03, 0x00, 0x00, 0x2c, 0x00, 0x01, 0x49, 0x6e, 0x50, 0x72, 0x1f, 0x41, 0x41, 0x75, 0x78, 0x69, 0x6c, 0x69, 0x61, 0x72, 0x79, 0x20, 0x31, 0x00, 0x45, 0x52, 0x20, 0x53, 0x43, 0x52, 0x45, 0x45, 0x41, 0x75, 0x78, 0x31, 0x01, 0x27, 0x01, 0x00, 0x01, 0x00, 0x81, 0x52, 0x02, 0x00, 0x00, 0x2c, 0x00, 0x01, 0x49, 0x6e, 0x50, 0x72, 0x1f, 0x42, 0x41, 0x75, 0x78, 0x69, 0x6c, 0x69, 0x61, 0x72, 0x79, 0x20, 0x32, 0x00, 0x72, 0x61, 0x20, 0x31, 0x31, 0x00, 0x01, 0x00, 0x41, 0x75, 0x78, 0x32, 0x01, 0x60, 0x01, 0x00, 0x01, 0x00, 0x81, 0x31, 0x02, 0x00, 0x00, 0x2c, 0x00, 0x01, 0x49, 0x6e, 0x50, 0x72, 0x1f, 0x43, 0x41, 0x75, 0x78, 0x69, 0x6c, 0x69, 0x61, 0x72, 0x79, 0x20, 0x33, 0x00, 0x52, 0x45, 0x4c, 0x45, 0x53, 0x53, 0x00, 0x00, 0x41, 0x75, 0x78, 0x33, 0x01, 0x60, 0x01, 0x00, 0x01, 0x00, 0x81, 0x45, 0x02, 0x00, 0x00, 0x2c, 0x00, 0x01, 0x49, 0x6e, 0x50, 0x72, 0x1f, 0x44, 0x41, 0x75, 0x78, 0x69, 0x6c, 0x69, 0x61, 0x72, 0x79, 0x20, 0x34, 0x00, 0x72, 0x61, 0x20, 0x31, 0x33, 0x00, 0x84, 0xab, 0x41, 0x75, 0x78, 0x34, 0x01, 0x00, 0x01, 0x00, 0x01, 0x00, 0x81, 0x33, 0x02, 0x00, 0x00, 0x2c, 0x00, 0x01, 0x49, 0x6e, 0x50, 0x72, 0x1f, 0x45, 0x41, 0x75, 0x78, 0x69, 0x6c, 0x69, 0x61, 0x72, 0x79, 0x20, 0x35, 0x00, 0x72, 0x61, 0x20, 0x31, 0x34, 0x00, 0x20, 0x46, 0x41, 0x75, 0x78, 0x35, 0x01, 0x20, 0x01, 0x00, 0x01, 0x00, 0x81, 0x34, 0x02, 0x00, 0x00, 0x2c, 0x00, 0x01, 0x49, 0x6e, 0x50, 0x72, 0x1f, 0x46, 0x41, 0x75, 0x78, 0x69, 0x6c, 0x69, 0x61, 0x72, 0x79, 0x20, 0x36, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03, 0x00, 0x41, 0x75, 0x78, 0x36, 0x01, 0x00, 0x01, 0x00, 0x01, 0x00, 0x81, 0xa0, 0x02, 0x00]

		var cursor = 0
		let handler = PureMessageHandler()
		handler.when { (change: VideoSource.PropertiesChanged) in
			print(change.debugDescription + ",")
		}
		while cursor < initialInPr.count {
			let length = Int( UInt16(from: initialInPr[cursor...cursor+1]) )
			try! handler.handle(rawMessage: initialInPr[cursor+4 ..< cursor+length])
			cursor += length
		}

		print(initialInPr.count)

		let customMsgs = try! [
			VideoSource.PropertiesChanged(
				source: .input(14),
				longName: "Camera 15",
				shortName: "Cm15",
				externalInterfaces: [.sdi, .composite, .sVideo],
				kind: .sdi,
				availability: [],
				mixEffects: []
			),
			VideoSource.PropertiesChanged(
				source: .input(15),
				longName: "Camera 16",
				shortName: "Cm16",
				externalInterfaces: [.composite],
				kind: .sdi,
				availability: [],
				mixEffects: []
			),
			VideoSource.PropertiesChanged(
				source: .input(16),
				longName: "Camera 17",
				shortName: "Cm17",
				externalInterfaces: [],
				kind: .sdi,
				availability: [],
				mixEffects: [.me2AndFillSources]
			),
			VideoSource.PropertiesChanged(
				source: .input(17),
				longName: "Camera 18",
				shortName: "Cm18",
				externalInterfaces: [.sdi, .hdmi],
				kind: .sdi,
				availability: [],
				mixEffects: []
			),
			VideoSource.PropertiesChanged(
				source: .input(18),
				longName: "Camera 19",
				shortName: "Cm19",
				externalInterfaces: [],
				kind: .sdi,
				availability: [],
				mixEffects: []
			),
			VideoSource.PropertiesChanged(
				source: .input(19),
				longName: "Camera 20",
				shortName: "Cm20",
				externalInterfaces: [],
				kind: .sdi,
				availability: [],
				mixEffects: []
			),
			VideoSource.PropertiesChanged(
				source: .colorBars,
				longName: "Color Bars",
				shortName: "Bars",
				externalInterfaces: [],
				kind: .black,
				availability: [.multiviewer],
				mixEffects: []
			),
			VideoSource.PropertiesChanged(
				source: .color(0),
				longName: "Color 1",
				shortName: "Col1",
				externalInterfaces: [],
				kind: .black,
				availability: [.auxiliary, .multiviewer],
				mixEffects: []
			),
			VideoSource.PropertiesChanged(
				source: .color(1),
				longName: "Color 2",
				shortName: "Col2",
				externalInterfaces: [],
				kind: .black,
				availability: [.auxiliary, .multiviewer],
				mixEffects: []
			),
			VideoSource.PropertiesChanged(
				source: .mediaPlayer(0),
				longName: "Media Player 1",
				shortName: "MP1",
				externalInterfaces: [.sdi, .hdmi, .composite, .sVideo],
				kind: .black,
				availability: [.superSourceArt],
				mixEffects: [.me1AndFillSources]
			),
			VideoSource.PropertiesChanged(
				source: .mediaPlayerKey(0),
				longName: "Media Player 1 Key",
				shortName: "MP1K",
				externalInterfaces: [],
				kind: .black,
				availability: [.auxiliary, .superSourceArt],
				mixEffects: [.me1AndFillSources]
			),
			VideoSource.PropertiesChanged(
				source: .mediaPlayer(1),
				longName: "Media Player 2",
				shortName: "MP2",
				externalInterfaces: [],
				kind: .black,
				availability: [.superSourceArt],
				mixEffects: []
			),
			VideoSource.PropertiesChanged(
				source: .mediaPlayerKey(1),
				longName: "Media Player 2 Key",
				shortName: "MP2K",
				externalInterfaces: [.sdi, .composite, .composite],
				kind: .black,
				availability: [.auxiliary, .superSourceArt],
				mixEffects: []
			),
			VideoSource.PropertiesChanged(
				source: .superSource,
				longName: "PIP",
				shortName: "PIP",
				externalInterfaces: [],
				kind: .black,
				availability: [.multiviewer, .superSourceArt],
				mixEffects: [.me2AndFillSources]
			),
			VideoSource.PropertiesChanged(
				source: .keyMask(0),
				longName: "ME 1 Key 1 Mask",
				shortName: "M1K1",
				externalInterfaces: [],
				kind: .black,
				availability: [.multiviewer],
				mixEffects: []
			),
			VideoSource.PropertiesChanged(
				source: .keyMask(1),
				longName: "ME 1 Key 2 Mask",
				shortName: "M1K2",
				externalInterfaces: [.sdi, .composite, .composite],
				kind: .black,
				availability: [.multiviewer],
				mixEffects: []
			),
			VideoSource.PropertiesChanged(
				source: .keyMask(2),
				longName: "ME 2 Key 1 Mask",
				shortName: "M2K1",
				externalInterfaces: [],
				kind: .black,
				availability: [.multiviewer],
				mixEffects: []
			),
			VideoSource.PropertiesChanged(
				source: .keyMask(3),
				longName: "ME 2 Key 2 Mask",
				shortName: "M2K2",
				externalInterfaces: [],
				kind: .black,
				availability: [.multiviewer],
				mixEffects: [.me2AndFillSources]
			),
			VideoSource.PropertiesChanged(
				source: .downStreamKeyMask(0),
				longName: "DSK 1 Mask",
				shortName: "DK1M",
				externalInterfaces: [.sdi, .hdmi, .composite, .composite],
				kind: .black,
				availability: [.multiviewer],
				mixEffects: [.me1AndFillSources]
			),
			VideoSource.PropertiesChanged(
				source: .downStreamKeyMask(1),
				longName: "DSK 2 Mask",
				shortName: "DK2M",
				externalInterfaces: [],
				kind: .black,
				availability: [.multiviewer],
				mixEffects: [.me2AndFillSources]
			),
			VideoSource.PropertiesChanged(
				source: .program(me: 0),
				longName: "ME 1 PGM",
				shortName: "Pgm1",
				externalInterfaces: [],
				kind: .black,
				availability: [],
				mixEffects: [.me1AndFillSources]
			),
			VideoSource.PropertiesChanged(
				source: .preview(me: 0),
				longName: "ME 1 PVW",
				shortName: "Pvw1",
				externalInterfaces: [],
				kind: .black,
				availability: [],
				mixEffects: [.me1AndFillSources]
			),
			VideoSource.PropertiesChanged(
				source: .program(me: 1),
				longName: "ME 2 PGM",
				shortName: "Pgm2",
				externalInterfaces: [],
				kind: .black,
				availability: [],
				mixEffects: [.me1AndFillSources]
			),
			VideoSource.PropertiesChanged(
				source: .preview(me: 1),
				longName: "ME 2 PVW",
				shortName: "Pvw2",
				externalInterfaces: [],
				kind: .black,
				availability: [],
				mixEffects: [.me1AndFillSources, .me2AndFillSources]
			),
			VideoSource.PropertiesChanged(
				source: .cleanFeed(0),
				longName: "Clean Feed 1",
				shortName: "Cfd1",
				externalInterfaces: [],
				kind: .black,
				availability: [],
				mixEffects: []
			),
			VideoSource.PropertiesChanged(
				source: .cleanFeed(1),
				longName: "Clean Feed 2",
				shortName: "Cfd2",
				externalInterfaces: [],
				kind: .black,
				availability: [],
				mixEffects: [.me1AndFillSources]
			),
			VideoSource.PropertiesChanged(
				source: .auxiliary(0),
				longName: "Auxiliary 1",
				shortName: "Aux1",
				externalInterfaces: [.sdi, .hdmi, .composite],
				kind: .black,
				availability: [.auxiliary],
				mixEffects: [.me2AndFillSources]
			),
			VideoSource.PropertiesChanged(
				source: .auxiliary(1),
				longName: "Auxiliary 2",
				shortName: "Aux2",
				externalInterfaces: [],
				kind: .black,
				availability: [.auxiliary],
				mixEffects: [.me1AndFillSources]
			),
			VideoSource.PropertiesChanged(
				source: .auxiliary(2),
				longName: "Auxiliary 3",
				shortName: "Aux3",
				externalInterfaces: [],
				kind: .black,
				availability: [.auxiliary],
				mixEffects: [.me1AndFillSources]
			),
			VideoSource.PropertiesChanged(
				source: .auxiliary(3),
				longName: "Auxiliary 4",
				shortName: "Aux4",
				externalInterfaces: [],
				kind: .black,
				availability: [.auxiliary],
				mixEffects: [.me1AndFillSources, .me2AndFillSources]
			),
			VideoSource.PropertiesChanged(
				source: .auxiliary(4),
				longName: "Auxiliary 5",
				shortName: "Aux5",
				externalInterfaces: [],
				kind: .black,
				availability: [.auxiliary],
				mixEffects: []
			),
			VideoSource.PropertiesChanged(
				source: .auxiliary(5),
				longName: "Auxiliary 6",
				shortName: "Aux6",
				externalInterfaces: [],
				kind: .black,
				availability: [.auxiliary],
				mixEffects: []
			)
			].flatMap {$0.serialize()}

		print(customMsgs.count)
	}


    static var allTests = [
        ("testConnectionHandlers", testConnectionHandlers),
//		("testChangePreviewBus", testChangePreviewBus),
    ]
}
