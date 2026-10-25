//
//  RefreshAttemptsViewController.swift
//  AltStore
//
//  Created by Riley Testut on 7/31/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

@preconcurrency import UIKit
import CoreData

@objc(RefreshAttemptTableViewCell)
private final class RefreshAttemptTableViewCell: UITableViewCell
{
    @IBOutlet var successLabel: UILabel!
    @IBOutlet var dateLabel: UILabel!
    @IBOutlet var errorDescriptionLabel: UILabel!
}

final class RefreshAttemptsViewController: UITableViewController
{
    private lazy var dataSource = self.makeDataSource()
    
    private lazy var dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short
        return dateFormatter
    }()
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        self.tableView.dataSource = self.dataSource
        self.dataSource.contentView = self.tableView
    }
}

private extension RefreshAttemptsViewController
{
    func makeDataSource() -> FetchedResultsTableViewDataSource<RefreshAttempt>
    {
        let fetchRequest = RefreshAttempt.fetchRequest() as NSFetchRequest<RefreshAttempt>
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \RefreshAttempt.date, ascending: false)]
        fetchRequest.returnsObjectsAsFaults = false
        
        let dataSource = FetchedResultsTableViewDataSource(fetchRequest: fetchRequest, managedObjectContext: DatabaseManager.shared.viewContext)
        dataSource.cellConfigurationHandler = { [weak self] (cell, attempt, indexPath) in
            let cell = cell as! RefreshAttemptTableViewCell
            cell.dateLabel.text = self?.dateFormatter.string(from: attempt.date)
            cell.errorDescriptionLabel.text = attempt.errorDescription
            
            if attempt.isSuccess
            {
                cell.successLabel.text = NSLocalizedString("成功", comment: "")
                cell.successLabel.textColor = .refreshGreen
            }
            else
            {
                cell.successLabel.text = NSLocalizedString("失败", comment: "")
                cell.successLabel.textColor = .refreshRed
            }
        }
        
        let placeholderView = PlaceholderView()
        placeholderView.textLabel.text = NSLocalizedString("没有刷新记录", comment: "")
        placeholderView.detailTextLabel.text = NSLocalizedString("你使用 SideStore 的次数越多，iOS 就越常允许它在后台刷新应用。", comment: "")
        dataSource.placeholderView = placeholderView
        
        return dataSource
    }
}
