//
//  JSONTests.swift
//
//  Created by Daniel Kiedrowski on 17.11.16.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

import XCTest
import SwiftyJSON

class JSONTests: XCTestCase {
    
    func testDifferingTypes() {
        let A = Bundle("a")
        let B = Bundle(1)
        
        do {
            _ = try A.merged(with: B)
            XCTFail()
        } catch (let error) {
            let error = error as NSError
            XCTAssertEqual(error.code, ErrorWrongType)
            XCTAssertEqual(error.domain, ErrorDomain)
            XCTAssertEqual(error.userInfo[NSLocalizedDescriptionKey] as! String,
                           "Couldn't merge, because the JSONs differ in type on top level.")
        }
    }
    
    func testPrimitiveType() {
        let A = Bundle("a")
        let B = Bundle("b")
        XCTAssertEqual(try! A.merged(with: B), B)
    }
    
    func testMergeEqual() {
        let json = Bundle(["a": "A"])
        XCTAssertEqual(try! json.merged(with: json), json)
    }
    
    func testMergeUnequalValues() {
        let A = Bundle(["a": "A"])
        let B = Bundle(["a": "B"])
        XCTAssertEqual(try! A.merged(with: B), B)
    }
    
    func testMergeUnequalKeysAndValues() {
        let A = Bundle(["a": "A"])
        let B = Bundle(["b": "B"])
        XCTAssertEqual(try! A.merged(with: B), JSON(["a": "A", "b": "B"]))
    }
    
    func testMergeFilledAndEmpty() {
        let A = Bundle(["a": "A"])
        let B = Bundle([:])
        XCTAssertEqual(try! A.merged(with: B), A)
    }
    
    func testMergeEmptyAndFilled() {
        let A = Bundle([:])
        let B = Bundle(["a": "A"])
        XCTAssertEqual(try! A.merged(with: B), B)
    }
    
    func testMergeArray() {
        let A = Bundle(["a"])
        let B = Bundle(["b"])
        XCTAssertEqual(try! A.merged(with: B), Bundle(["a", "b"]))
    }
    
    func testMergeNestedJSONs() {
        let A = Bundle([
            "nested": [
                "A": "a"
            ]
        ])
        
        let B = Bundle([
            "nested": [
                "A": "b"
            ]
        ])
        
        XCTAssertEqual(try! A.merged(with: B), B)
    }
}
