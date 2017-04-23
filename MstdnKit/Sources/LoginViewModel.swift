//
//  LoginViewModel.swift
//  mstdn
//
//  Created by tarunon on 2017/04/23.
//  Copyright © 2017年 tarunon. All rights reserved.
//

import Foundation
import UIKitExtensions
import RxSwift
import RxCocoa
import Persistents
import APIClient

public protocol LoginViewModelOwner {
    var hostName: Observable<String> { get }
    var email: Observable<String> { get }
    var password: Observable<String> { get }
    var cancelButtonTapped: Observable<Void> { get }
    var loginButtonTapped: Observable<Void> { get }
    
    func apiClient(hostName: String) -> APIClient.Client
    func clientPersistent(hostName: String) -> PersistentStore<Client>
}

public class LoginViewModel<O: LoginViewModelOwner>: RxViewModel {
    public typealias Owner = O
    public typealias Result = Token
    public let result: Observable<Token>
    
    public init(owner: O) {
        result = owner.loginButtonTapped
            .withLatestFrom(owner.hostName)
            .withLatestFrom(owner.email) { ($0, $1) }
            .withLatestFrom(owner.password) { ($0.0, $0.1, $1) }
            .filter { !($0.isEmpty || $1.isEmpty || $2.isEmpty) }
            .flatMapFirst { (hostName, email, password) -> Observable<Token> in
                let persisntent = owner.clientPersistent(hostName: hostName)
                let apiClient = owner.apiClient(hostName: hostName)
                return Observable
                    .just(persisntent)
                    .map { try $0.restore() }
                    .catchError { _ in
                        apiClient.request(request: try Requests.Apps(Client.Form()))
                            .do(onNext: persisntent.store)
                    }
                    .flatMapFirst { (client) in
                        apiClient.request(request: Requests.Oauth(client, email: email, password: password))
                }
            }
            .take(1)
            .amb(
                owner.cancelButtonTapped
                    .take(1)
                    .flatMap { _ in Observable.empty() }
            )
    }
}
