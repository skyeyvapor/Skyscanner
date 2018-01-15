//
//  ViewController.swift
//  Skyscanner
//
//  Created by Ching-Lan Chen on 2018/1/4.
//  Copyright © 2018年 Ching-Lan Chen. All rights reserved.
//

import UIKit
import Alamofire
import SwiftyJSON


class ViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    @IBOutlet weak var tableView: UITableView!
    
    @IBOutlet weak var resultsLabel: UILabel!
    @IBOutlet weak var sortButton: UIButton!
    
    
    
    var itinerariesJSONArray = [JSON]()
    var polledBookingDetails = [JSON]()
    var legsJSONArray = [JSON]()
    var carriersDict = [Int: JSON]()
    
    var isAnimating = false
    let refreshControl = UIRefreshControl()
    
    let address: String = "http://partners.api.skyscanner.net/apiservices/pricing/v1.0"
    
    let headers: HTTPHeaders = [
        "Content-Type": "application/x-www-form-urlencoded"
    ]
    
    let apikey = APIKey
    var sessionKey: String!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        
        tableView.register(UINib(nibName: "CustomTableCell", bundle: Bundle.main), forCellReuseIdentifier: "CustomCell")
        
        tableView.delegate = self
        tableView.dataSource = self

        tableView.addSubview(refreshControl)
        
        tableView.setContentOffset(CGPoint(x: 0, y: -refreshControl.frame.size.height), animated: true)
        refreshControl.beginRefreshing()
        resultsLabel?.text = "Reading......"
        //tableView.reloadData()
        
        loadFlightsLivePrices()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        //tableView.reloadData()
        
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return itinerariesJSONArray.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CustomCell", for: indexPath as IndexPath) as! CustomTableCell
        
        //cell.textLabel?.text = dataArray[indexPath.row].rawString()
        
        var cheapestPrice: Int? = nil
        for pricingOption in itinerariesJSONArray[indexPath.row]["PricingOptions"].arrayValue {
            if cheapestPrice == nil {
                cheapestPrice = pricingOption["Price"].int!
            } else {
                cheapestPrice = min(cheapestPrice!, pricingOption["Price"].int!)
            }
        }
        cell.priceLabel?.text = "£" + String(describing: cheapestPrice!)
        
        for leg in legsJSONArray {
            
            // outbound
            if leg["Id"].rawString() == itinerariesJSONArray[indexPath.row]["OutboundLegId"].rawString() {
                
                let outboundTime = changeDateFormat(dateString: leg["Departure"].rawString()!) + " - " + changeDateFormat(dateString: leg["Arrival"].rawString()!)
                cell.outboundTimeLabel?.text = outboundTime
                
                let carrierId = leg["Carriers"].arrayValue[0].int!
                cell.outboundStationLabel?.text = "EDI - LCY, " + String(describing: carriersDict[carrierId]!["Name"]) //carrier
                
                
                let url = URL(string: carriersDict[carrierId]!["ImageUrl"].string!)
                let data = try? Data(contentsOf: url!) //make sure your image in this url does exist, otherwise unwrap in a if let check / try-catch
                cell.outboundImageView.image = UIImage(data: data!)
                
                
                let duration = leg["Duration"].int!
                cell.outboundDurationLabel?.text = stringFromTimeInterval(interval: String(describing: duration))
            }
            
            
            // inbound
            if leg["Id"].rawString() == itinerariesJSONArray[indexPath.row]["InboundLegId"].rawString() {
                
                let inboundTime = changeDateFormat(dateString: leg["Departure"].rawString()!) + " - " + changeDateFormat(dateString: leg["Arrival"].rawString()!)
                cell.inboundTimeLabel?.text = inboundTime
                
                let carrierId = leg["Carriers"].arrayValue[0].int!
                cell.inboundStationLabel?.text = "LCY - EDI, " + String(describing: carriersDict[carrierId]!["Name"]) //carrier
                
                let url = URL(string: carriersDict[carrierId]!["ImageUrl"].string!)
                let data = try? Data(contentsOf: url!) //make sure your image in this url does exist, otherwise unwrap in a if let check / try-catch
                cell.inboundImageView.image = UIImage(data: data!)
                
                let duration = leg["Duration"].int!
                cell.inboundDurationLabel?.text = stringFromTimeInterval(interval: String(describing: duration))
            }
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        
        return 240
    }
    
    // When scroll end decelerating, refresh
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        print("scrollViewDidEndDecelerating")
        if (refreshControl.isRefreshing) {
            if !isAnimating {
                print("endRefreshing")
                isAnimating = true
                loadFlightsLivePrices()
            }
        }
    }
    
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func getNextMonday() -> (String, String) {
        let today = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US")
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let calendar = Calendar.current
        let todayWeekday = calendar.component(.weekday, from: today)
        
        let addToMonday = todayWeekday == 1 ? 1: 9 - todayWeekday
        var components = DateComponents()
        components.weekday = addToMonday
        
        let nextMonday = calendar.date(byAdding: .day, value: addToMonday, to: today)
        //print("nextMonday", nextMonday!.localString())
    
        components.weekday = addToMonday + 1
        let nextTuesday = calendar.date(byAdding: components, to: today)
        //print("nextTuesday", nextTuesday!.localString())
    
        let newMonday = dateFormatter.string(from: nextMonday!)
        let newTuesday = dateFormatter.string(from: nextTuesday!)
        return (newMonday, newTuesday)
    }
    
    func loadFlightsLivePrices() {

        let (newMonday, newTuesday) = getNextMonday()

        let parameters = [
            "cabinclass": "Economy",
            "country": "UK",
            "currency": "GBP",
            "locale": "en-GB",
            "locationSchema": "iata",
            "originplace": "EDI",
            "destinationplace": "LCY",
            "outbounddate": newMonday,
            "inbounddate": newTuesday,
            "adults": "1",
            "children": "0",
            "infants": "0",
            "apikey": apikey
        ]
        
        let locationParameters = [
            "apiKey": apikey,
            "stops": "0"
        ]

        let group1 = DispatchGroup()
        // creatingTheSession
        group1.enter()
        print("First group")
        creatingTheSession(group: group1, address: address, parameters: parameters, headers: headers)
        

        
        group1.notify(queue: DispatchQueue.main) {
            
            let group2 = DispatchGroup()
            print("Second Group")
            
            //print("sessionKey", sessionKey)
            
            group2.enter()
            
            self.pollingTheResults(group: group2, address: "http://partners.api.skyscanner.net/apiservices/pricing/uk1/v1.0/" + self.sessionKey, parameters: locationParameters)

            
            group2.notify(queue: DispatchQueue.main) {
                let number = String(self.itinerariesJSONArray.count)
                self.resultsLabel?.text = number + " of " + number + " results shown"
                self.isAnimating = false
                self.refreshControl.endRefreshing()
                self.tableView.reloadData()
                
            } //End group2
            
        }//End group1
    }
    
    // To create the session
    func creatingTheSession(group: DispatchGroup, address: String, parameters: [String: String], headers: [String: String]){
        Alamofire.request(address, method:.post, parameters: parameters, headers: headers) .responseJSON { response in
            
            print("Original URL request: ", response.request as Any)
            print("URL response: ",response.response as Any)
            print("Server data: ",response.data as Any)
            print("Serial result of response: ",response.result)
            
            self.resultsLabel?.text = "Linking server: " + String(describing: response.result)
            let url = URL(string: (response.response as HTTPURLResponse!).allHeaderFields["Location"] as! String)
            self.sessionKey = url!.pathComponents.last!  // Get sessionKey
            print(self.sessionKey)
            group.leave()
        }
    }
    
    // To poll the results
    func pollingTheResults(group: DispatchGroup, address: String, parameters: [String: String]) {
        Alamofire.request(address, method:.get, parameters: parameters) .responseJSON { response in
            print("Original URL request: ", response.request as Any)
            print("URL response: ",response.response as Any)
            print("Server data: ",response.data as Any)
            print("Serial result of response: ",response.result)
            
            self.resultsLabel?.text = "Polling data: " + String(describing: response.result)
            
            if let value = response.result.value {
                let jsonValue = JSON(value)
                
                // Find OutboundLegId in Itineraries
                if let itineraries = jsonValue["Itineraries"].array {
                    //print("type", type(of: itineraries))  // type Array<JSON>
                    self.itinerariesJSONArray = itineraries
                    //print("Itineraries: ", itineraries)
                } else {
                    print("error")
                }
                if let legs = jsonValue["Legs"].array {
                    self.legsJSONArray = legs
                }
                
                if let carriers = jsonValue["Carriers"].array {
                    
                    
                    for carrier in carriers {
                        self.carriersDict[carrier["Id"].int!] = carrier
                    }
                }
                
                //print(self.itinerariesJSONArray)
            }
            group.leave()
        }
    }
    
    // To convert duration String (e.g. 100 to 1h 40m)
    func stringFromTimeInterval(interval: String) -> String {
        let endingDate = Date()
        if let timeInterval = TimeInterval(interval) {
            let startingDate = endingDate.addingTimeInterval(-timeInterval * 60)
            let calendar = Calendar.current
            
            var componentsNow = calendar.dateComponents([.hour, .minute], from: startingDate, to: endingDate)
            if let hour = componentsNow.hour, let minute = componentsNow.minute {
                return "\(hour)h \(minute)m"
            } else {
                return "0h 0m"
            }
            
        } else {
            return "0h 0m"
        }
    }
    
    // To change departure/arrival date String(e.g. 2018-02-10T19:00:00) to a time String contains only hours and minute(19:00)
    func changeDateFormat(dateString: String) -> String {
        let time = dateString.components(separatedBy: "T")[1]
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss"
        let timeDate = dateFormatter.date(from: time)
        dateFormatter.dateFormat = "HH:mm"
        let changedTime = dateFormatter.string(from: timeDate!)
        return changedTime
    }
}

// To convert Date to local format
extension Date {
    func localString(dateStyle: DateFormatter.Style = .medium, timeStyle: DateFormatter.Style = .medium) -> String {
        return DateFormatter.localizedString(from: self, dateStyle: dateStyle, timeStyle: timeStyle)
    }
}

