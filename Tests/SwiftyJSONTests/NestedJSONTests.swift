//
//  NestedJSONTests.swift
//  SwiftyJSON
//
//  Created by Hector Matos on 9/27/16.
//
//

import XCTest
import SwiftyJSON

class NestedJSONTests: XCTestCase {
    let family: Bundle = [
        "names" : [
            "Brooke Abigail Matos",
            "Rowan Danger Matos"
        ],
        "motto" : "Hey, I don't know about you, but I'm feeling twenty-two! So, release the KrakenDev!"
    ]
    
    func testTopLevelNestedJSON() {
        let nestedJSON: Bundle = [
            "family" : family
        ]
        XCTAssertNotNil(try? nestedJSON.rawData())
    }
    
    func testDeeplyNestedJSON() {
        let nestedFamily: Bundle = [
            "count": 1,
            "families": [
                [
                    "isACoolFamily" : true,
                    "family" : [
                        "hello" : family
                    ]
                ]
            ]
        ]
        XCTAssertNotNil(try? nestedFamily.rawData())
    }
}
