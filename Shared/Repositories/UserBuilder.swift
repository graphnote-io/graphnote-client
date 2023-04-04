//
//  UserBuilder.swift
//  Graphnote (macOS)
//
//  Created by Hayden Pennington on 3/26/23.
//

import Foundation

struct UserBuilder {
    private static let moc = DataController.shared.container.viewContext
    
    static func create(user: User) throws {
        let userEntity = UserEntity(entity: UserEntity.entity(), insertInto: moc)
        userEntity.id = user.id
        userEntity.createdAt = user.createdAt
        userEntity.modifiedAt = user.modifiedAt
        
        do {
            try moc.save()
        } catch let error {
            print(error)
            throw error
        }
        
    }
}
