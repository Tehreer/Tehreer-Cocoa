//
// Copyright (C) 2019 Muhammad Tayyab Akram
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

import Foundation

class IntrinsicCollection<T> {
    var count: Int {
        get {
            fatalError()
        }
    }

    func item(at index: Int) -> T {
        fatalError()
    }
}

extension IntrinsicCollection {
    func map<O>(_ operation: @escaping (_ : T) -> O) -> IntrinsicCollection<O> {
        return IntrinsicMapCollection(base: self, operation: operation)
    }
}

fileprivate class IntrinsicMapCollection<Input, Output>: IntrinsicCollection<Output> {
    let base: IntrinsicCollection<Input>
    let operation: (_ : Input) -> Output

    init(base: IntrinsicCollection<Input>, operation: @escaping (_ : Input) -> Output) {
        self.base = base
        self.operation = operation
    }

    override var count: Int {
        return base.count
    }

    override func item(at index: Int) -> Output {
        return operation(base.item(at: index))
    }
}
