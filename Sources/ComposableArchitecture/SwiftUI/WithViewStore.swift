import CustomDump
import SwiftUI


public struct WithViewStore<ViewState, ViewAction, Content: View>: View {
  private let content: (ViewStore<ViewState, ViewAction>) -> Content
  #if DEBUG
    private let file: StaticString
    private let line: UInt
    private var prefix: String?
    private var previousState: (ViewState) -> ViewState?
    private var storeTypeName: String
  #endif
  @ObservedObject private var viewStore: ViewStore<ViewState, ViewAction>

  init(
    store: Store<ViewState, ViewAction>,
    removeDuplicates isDuplicate: @escaping (ViewState, ViewState) -> Bool,
    content: @escaping (ViewStore<ViewState, ViewAction>) -> Content,
    file: StaticString = #fileID,
    line: UInt = #line
  ) {
    self.content = content
    #if DEBUG
      self.file = file
      self.line = line
      var previousState: ViewState? = nil
      self.previousState = { currentState in
        defer { previousState = currentState }
        return previousState
      }
      self.storeTypeName = ComposableArchitecture.storeTypeName(of: store)
    #endif
    self.viewStore = ViewStore(store, observe: { $0 }, removeDuplicates: isDuplicate)
  }

  #if swift(>=5.8)
    /// Prints debug information to the console whenever the view is computed.
    ///
    /// - Parameter prefix: A string with which to prefix all debug messages.
    /// - Returns: A structure that prints debug messages for all computations.
    @_documentation(visibility:public)
    public func _printChanges(_ prefix: String = "") -> Self {
      var view = self
      #if DEBUG
        view.prefix = prefix
      #endif
      return view
    }
  #else
    public func _printChanges(_ prefix: String = "") -> Self {
      var view = self
      #if DEBUG
        view.prefix = prefix
      #endif
      return view
    }
  #endif

  public var body: Content {
    #if DEBUG
      Logger.shared.log("WithView\(storeTypeName).body")
      if let prefix = self.prefix {
        var stateDump = ""
        customDump(self.viewStore.state, to: &stateDump, indent: 2)
        let difference =
          self.previousState(self.viewStore.state)
          .map {
            diff($0, self.viewStore.state).map { "(Changed state)\n\($0)" }
              ?? "(No difference in state detected)"
          }
          ?? "(Initial state)\n\(stateDump)"
        print(
          """
          \(prefix.isEmpty ? "" : "\(prefix): ")\
          WithViewStore<\(typeName(ViewState.self)), \(typeName(ViewAction.self)), _>\
          @\(self.file):\(self.line) \(difference)
          """
        )
      }
    #endif
    return self.content(ViewStore(self.viewStore))
  }

  public init<State, Action>(
    _ store: Store<State, Action>,
    observe toViewState: @escaping (_ state: State) -> ViewState,
    send fromViewAction: @escaping (_ viewAction: ViewAction) -> Action,
    removeDuplicates isDuplicate: @escaping (_ lhs: ViewState, _ rhs: ViewState) -> Bool,
    @ViewBuilder content: @escaping (_ viewStore: ViewStore<ViewState, ViewAction>) -> Content,
    file: StaticString = #fileID,
    line: UInt = #line
  ) {
    self.init(
      store: store.scope(
        id: nil,
        state: ToState(toViewState),
        action: fromViewAction,
        isInvalid: nil
      ),
      removeDuplicates: isDuplicate,
      content: content,
      file: file,
      line: line
    )
  }

  public init<State>(
    _ store: Store<State, ViewAction>,
    observe toViewState: @escaping (_ state: State) -> ViewState,
    removeDuplicates isDuplicate: @escaping (_ lhs: ViewState, _ rhs: ViewState) -> Bool,
    @ViewBuilder content: @escaping (_ viewStore: ViewStore<ViewState, ViewAction>) -> Content,
    file: StaticString = #fileID,
    line: UInt = #line
  ) {
    self.init(
      store: store.scope(
        id: nil,
        state: ToState(toViewState),
        action: { $0 },
        isInvalid: nil
      ),
      removeDuplicates: isDuplicate,
      content: content,
      file: file,
      line: line
    )
  }
}

extension WithViewStore where ViewState: Equatable, Content: View {

  public init<State, Action>(
    _ store: Store<State, Action>,
    observe toViewState: @escaping (_ state: State) -> ViewState,
    send fromViewAction: @escaping (_ viewAction: ViewAction) -> Action,
    @ViewBuilder content: @escaping (_ viewStore: ViewStore<ViewState, ViewAction>) -> Content,
    file: StaticString = #fileID,
    line: UInt = #line
  ) {
    self.init(
      store: store.scope(
        id: nil,
        state: ToState(toViewState),
        action: fromViewAction,
        isInvalid: nil
      ),
      removeDuplicates: ==,
      content: content,
      file: file,
      line: line
    )
  }

  public init<State>(
    _ store: Store<State, ViewAction>,
    observe toViewState: @escaping (_ state: State) -> ViewState,
    @ViewBuilder content: @escaping (_ viewStore: ViewStore<ViewState, ViewAction>) -> Content,
    file: StaticString = #fileID,
    line: UInt = #line
  ) {
    self.init(
      store: store.scope(
        id: nil,
        state: ToState(toViewState),
        action: { $0 },
        isInvalid: nil
      ),
      removeDuplicates: ==,
      content: content,
      file: file,
      line: line
    )
  }
}

extension WithViewStore: DynamicViewContent
where
  ViewState: Collection,
  Content: DynamicViewContent
{
  public typealias Data = ViewState

  public var data: ViewState {
    self.viewStore.state
  }
}
