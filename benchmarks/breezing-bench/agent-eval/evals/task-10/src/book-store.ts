import type { Book, CreateBookInput, UpdateBookInput, PaginatedResponse, BookStore } from './types';

export class InMemoryBookStore implements BookStore {
  private books = new Map<string, Book>();
  private nextId = 1;

  create(input: CreateBookInput): Book {
    // TODO: validate title is not empty (throw Error)
    // TODO: validate author is not empty (throw Error)
    // TODO: check ISBN is not duplicate (use findByIsbn, throw Error if exists)
    // TODO: create Book object with:
    //   - id: string from this.nextId++
    //   - all fields from input
    //   - createdAt: new Date()
    //   - updatedAt: new Date()
    // TODO: add to this.books map and return
    throw new Error('Not implemented');
  }

  getById(id: string): Book | undefined {
    return this.books.get(id);
  }

  getAll(page: number = 1, pageSize: number = 10): PaginatedResponse<Book> {
    const allBooks = Array.from(this.books.values());
    const total = allBooks.length;
    const totalPages = Math.ceil(total / pageSize);
    // TODO: calculate start index = (page - 1) * pageSize
    // TODO: slice allBooks for current page
    // TODO: return PaginatedResponse with items, total, page, pageSize, totalPages
    throw new Error('Not implemented');
  }

  update(id: string, input: UpdateBookInput): Book | undefined {
    // TODO: find book by id, return undefined if not found
    // TODO: apply updates from input (only defined fields)
    // TODO: update updatedAt timestamp
    // TODO: return updated book
    throw new Error('Not implemented');
  }

  delete(id: string): boolean {
    return this.books.delete(id);
  }

  findByIsbn(isbn: string): Book | undefined {
    return Array.from(this.books.values()).find(b => b.isbn === isbn);
  }
}
