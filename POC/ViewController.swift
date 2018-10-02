//
//  ViewController.swift
//  POC
//
//  Created by Kalpesh Talkar on 02/10/18.
//  Copyright © 2018 Kalpesh Talkar. All rights reserved.
//

import UIKit
import Starscream

class ViewController: UIViewController, WebSocketDelegate {

    // MARK: - IBActons
    @IBOutlet private weak var infoLbl: UILabel!

    var socket: WebSocket? = nil
    var usdRate = Float(0)

    // MARK: - Life cycle methids
    override func viewDidLoad() {
        super.viewDidLoad()
        //initialSetup()
        getRates()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if usdRate > 0 {
            initialSetup()
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        cleanup()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        cleanup()
    }

    // MARK: - Prepare UI
    private func initialSetup() {
        socket = WebSocket(url: URL(string: "wss://ws.blockchain.info/inv")!)
        socket!.delegate = self
        socket!.connect()
    }

    private func cleanup() {
        if socket != nil {
            subBlocks(sub: false)
            subUT(sub: false)
            socket!.disconnect()
            socket = nil
        }
    }

    private func ping() {
        let str = "{\"op\":\"ping\"}"
        socket!.write(string: str)
    }

    private func subUT(sub: Bool = true) {
        var str = "{\"op\":\"unconfirmed_sub\"}"
        if !sub {
            str = "{\"op\":\"unconfirmed_unub\"}"
        }
        socket?.write(string: str)
    }

    private func subBlocks(sub: Bool = true) {
        var str = "{\"op\":\"blocks_sub\"}"
        if !sub {
            str = "{\"op\":\"blocks_unsub\"}"
        }
        //let str = "{\"op\":\"blocks_sub\"}"
        socket?.write(string: str)
    }

    // MARK: - WebSocketDelegate
    func websocketDidConnect(socket: WebSocketClient) {
        print("Connected")
        ping()
        subUT()
        subBlocks()
    }

    func websocketDidDisconnect(socket: WebSocketClient, error: Error?) {
        print("Disconnected")
    }

    func websocketDidReceiveData(socket: WebSocketClient, data: Data) {
        print("Received data")
    }

    func websocketDidReceiveMessage(socket: WebSocketClient, text: String) {
        print("Received message: \(text)")
        // dictionary parse data here...
        do {
            let data = text.data(using: String.Encoding.utf8)!
            if let json =  try JSONSerialization.jsonObject(with: data, options: []) as? Dictionary<String, Any> {
                let b = Block(json: json)
                updateUI(block: b)
            }
        } catch {
            print(error.localizedDescription)
        }
    }

    let min = Float(0.002)

    // MARK: - Update UI
    private func updateUI(block: Block) {
        // more than 0.002 BTC
        if block.totalOut >= min {
            infoLbl.text = "OP: \(block.respType)\nHash: \(block.hash)\nSize: \(block.size)\nTotal BTC Sent: \(block.totalOut)\nR0eward: \(block.reward)\nUSD: \(block.totalOut * usdRate)"
        } else {
            print("Less than 0.002 BTC: \(block.hash)")
        }
    }

    private func getRates() {
        print("Geting currency rates")
        let url = "https://blockchain.info/ticker"
        let request : NSMutableURLRequest = NSMutableURLRequest()
        request.url = URL(string: url)
        request.httpMethod = "GET"

        NSURLConnection.sendAsynchronousRequest(request as URLRequest, queue: OperationQueue()) { (resp, dat, error) in

            if dat != nil {
                do {
                    if let json =  try JSONSerialization.jsonObject(with: dat!, options: []) as? Dictionary<String, Any> {
                        print("Currency rates fetched")
                        if let usd = json["USD"] as? Dictionary<String, Any> {
                            if let val = usd["last"] as? Float {
                                self.usdRate = val
                                self.initialSetup()
                            }
                        }
                    }
                } catch {
                    print(error.localizedDescription)
                }
            } else {
                print("Error")
            }
        }
    }

}

class Block {

    var respType = ""

    var hash = ""
    var size = 0
    var totalBTCSent = 0
    var reward = 0

    var outList = Array<Out>()

    var totalOut = Float(0)

    init(json: Dictionary<String, Any>? = nil) {
        if json != nil {
            if let value = json!["op"] as? String {
                respType = value
            }
            if let dict = json!["x"] as? Dictionary<String,Any> {
                if let value = dict["hash"]
                    as? String {
                    hash = value
                }
                if let value = dict["size"] as? Int {
                    size = value
                }
                if let value = dict["totalBTCSent"] as? Int {
                    totalBTCSent = value
                }
                if let value = dict["reward"] as? Int {
                    reward = value
                }
                if let value = dict["out"] as? Array<Dictionary<String,Any>> {
                    for val in value {
                        let out = Out(json: val)
                        outList.append(out)

                        totalOut += out.amt
                    }
                }
            }
        }
    }

}

class Out {

    var amt = Float(0)

    init(json: Dictionary<String, Any>? = nil) {
        if json != nil {
            if let value = json!["value"] as? Int {
                amt = satoshiToBTC(satoshi: value)
            }
        }
    }

    private func satoshiToBTC(satoshi: Int) -> Float {
        return Float(satoshi) / Float(100000000)
    }
}

//typedef JSONObject as Dictionary<String, Any>

