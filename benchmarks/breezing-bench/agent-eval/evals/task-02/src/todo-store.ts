import type { Todo, CreateTodoInput, UpdateTodoInput, TodoStore } from './types';

export class InMemoryTodoStore implements TodoStore {
  private todos = new Map<string, Todo>();
  private nextId = 1;

  create(input: CreateTodoInput): Todo {
    // TODO: validate that title is not empty (throw Error if empty)
    // TODO: create a Todo object with:
    //   - id: string from this.nextId++ (convert to string)
    //   - title: from input
    //   - description: from input (optional)
    //   - completed: false
    //   - createdAt: new Date()
    //   - updatedAt: new Date()
    // TODO: add to this.todos map and return the Todo
    throw new Error('Not implemented');
  }

  getById(id: string): Todo | undefined {
    return this.todos.get(id);
  }

  getAll(): Todo[] {
    // TODO: return all todos as an array
    throw new Error('Not implemented');
  }

  update(id: string, input: UpdateTodoInput): Todo | undefined {
    // TODO: find the todo by id
    // TODO: if not found, return undefined
    // TODO: apply updates from input (only defined fields)
    // TODO: update the updatedAt timestamp
    // TODO: return the updated todo
    throw new Error('Not implemented');
  }

  delete(id: string): boolean {
    // TODO: delete from map, return true if existed, false otherwise
    throw new Error('Not implemented');
  }
}
