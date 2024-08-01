//
//  WeatherDataLoader.swift
//  LetsGetWeather
//
//  Created by Dmytro Yaremyshyn on 25/06/2024.
//

import Foundation
import Combine

public protocol WeatherDataLoader {
    typealias Result = AnyPublisher<WeatherResponse, Error>

    func loadData(from url: URL) -> Result
}
