//
//  WeatherViewController.swift
//  LetsGetWeather
//
//  Created by Dmytro Yaremyshyn on 25/06/2024.
//

import UIKit
import Combine
import GooglePlaces

public class WeatherViewController: UITableViewController {
    
    lazy var resultsViewController: GMSAutocompleteResultsViewController = {
        let viewController = GMSAutocompleteResultsViewController()
        viewController.delegate = self
        return viewController
    }()
    
    lazy var searchController: UISearchController = {
        let searchController = UISearchController(searchResultsController: resultsViewController)
        searchController.searchResultsUpdater = resultsViewController
        searchController.searchBar.sizeToFit()
        searchController.searchBar.placeholder = viewModel?.searchPlaceholder
        searchController.hidesNavigationBarDuringPresentation = false
        return searchController
    }()
    
    lazy var errorView: ErrorView = {
        let view = ErrorView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
        
    private var cancellables = Set<AnyCancellable>()
    var viewModel: WeatherViewModel? {
        didSet { bind() }
    }
    
    // MARK: Lifecycle
    public override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
        viewModel?.loadData()
    }
    
    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableView.sizeTableHeaderToFit()
    }

    private func bind() {
        viewModel?.$placesList
            .receive(on: DispatchQueue.main)
            .sink { [weak self] results in self?.tableView.reloadData() }
            .store(in: &cancellables)
        
        viewModel?.$fetchedWeather
            .receive(on: DispatchQueue.main)
            .sink { [weak self] weather in
                guard let self, let weather = weather else { return }
                self.showAlert(for: weather)
            }
            .store(in: &cancellables)
        
        viewModel?.$errorMessage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in self?.display(errorMessage: message) }
            .store(in: &cancellables)
    }
    
    private func setupView() {
        view.backgroundColor = .systemBackground

        addSearchBarToNavigationItem()
        
        tableView.register(WeatherViewCell.self, forCellReuseIdentifier: WeatherViewCell.identifier)
        tableView.dataSource = self
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 120
        tableView.separatorStyle = .none
        tableView.tableHeaderView = errorView.makeContainer()
        
        errorView.onHide = { [weak self] in
            self?.tableView.beginUpdates()
            self?.tableView.sizeTableHeaderToFit()
            self?.tableView.endUpdates()
        }
    }
    
    private func showAlert(for weather: WeatherModel) {
        showAlert(title: viewModel?.alertTitle, message: viewModel?.alertMessage, actionTitle: viewModel?.alertCancel)
    }
    
    @objc func search() {
        viewModel?.fetchWeatherFor(location: searchController.searchBar.text)
    }
}

// MARK: Google Place API Integration
extension WeatherViewController: GMSAutocompleteResultsViewControllerDelegate {
    
    private func addSearchBarToNavigationItem() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "magnifyingglass"), style: .done, target: self, action: #selector(search))

        navigationItem.titleView = searchController.searchBar
        // When UISearchController presents the results view, present it in
        // this view controller, not one further up the chain.
        definesPresentationContext = true
    }
    
    public func resultsController(_ resultsController: GMSAutocompleteResultsViewController, didAutocompleteWith place: GMSPlace) {
        display(errorMessage: nil)
        searchController.isActive = false
        searchController.searchBar.text = place.formattedAddress
        viewModel?.selected(location: GooglePlace.map(place: place))
    }
    
    public func resultsController(_ resultsController: GMSAutocompleteResultsViewController, didFailAutocompleteWithError error: any Error) {
        display(errorMessage: viewModel?.autocompleteErrorMessage)
    }
}

//MARK: TableView DataSource
extension WeatherViewController {
    
    public override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel?.placesList.count ?? 0
    }

    public override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        guard let cell = tableView.dequeueReusableCell(withIdentifier: WeatherViewCell.identifier, for: indexPath) as? WeatherViewCell else {
            return UITableViewCell()
        }
        cell.updateCell(model: viewModel?.placesList[indexPath.row])
        return cell
    }

    public override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selectedLocation = viewModel?.placesList[indexPath.row]
        viewModel?.selected(location: selectedLocation?.selectedPlace)
        viewModel?.fetchWeatherFor(location: selectedLocation?.selectedPlace?.formattedAddress ?? .none)
    }
    
    public override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        viewModel?.placesList.count ?? 0 > 0 ? viewModel?.tableHeaderTitle : .none
    }
    
    override public func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            viewModel?.removeSearchedPlace(index: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .fade)
        }
    }
    
    override public func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        .delete
    }
}

//MARK: Display Weather Error protocol 
extension WeatherViewController: WeatherErrorView {
    // Displaying error message in the header table view
    public func display(errorMessage: String?) {
        searchController.isActive = false
        errorView.message = errorMessage
        if errorMessage != nil {
            tableView.reloadData()
        }
    }
}
