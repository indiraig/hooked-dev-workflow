import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import UserSearch from '../components/UserSearch'
import * as userApi from '../services/userApi'

// Mock the API module
vi.mock('../services/userApi')

const MOCK_USERS = [
  { id: 1, name: 'John Doe',   email: 'john.doe@example.com', role: 'Engineer', department: 'Backend'  },
  { id: 2, name: 'Jane Smith', email: 'jane.s@example.com',   role: 'Designer', department: 'Frontend' },
]

describe('UserSearch', () => {
  beforeEach(() => {
    vi.resetAllMocks()
  })

  it('renders search input and button', () => {
    render(<UserSearch />)
    expect(screen.getByRole('textbox', { name: /search users/i })).toBeTruthy()
    expect(screen.getByRole('button', { name: /search/i })).toBeTruthy()
  })

  it('calls searchUsers with the input value on form submit', async () => {
    userApi.searchUsers.mockResolvedValue(MOCK_USERS)
    render(<UserSearch />)

    await userEvent.type(screen.getByPlaceholderText(/search/i), 'john')
    fireEvent.click(screen.getByRole('button', { name: /search/i }))

    await waitFor(() => {
      expect(userApi.searchUsers).toHaveBeenCalledWith('john')
    })
  })

  it('displays results after a successful search', async () => {
    userApi.searchUsers.mockResolvedValue(MOCK_USERS)
    render(<UserSearch />)

    await userEvent.type(screen.getByPlaceholderText(/search/i), 'john')
    fireEvent.click(screen.getByRole('button', { name: /search/i }))

    await waitFor(() => {
      expect(screen.getByText('John Doe')).toBeTruthy()
      expect(screen.getByText('Jane Smith')).toBeTruthy()
    })
  })

  it('shows "2 results found" count', async () => {
    userApi.searchUsers.mockResolvedValue(MOCK_USERS)
    render(<UserSearch />)

    fireEvent.click(screen.getByRole('button', { name: /search/i }))

    await waitFor(() => {
      expect(screen.getByText(/2 results found/i)).toBeTruthy()
    })
  })

  it('shows "No users match" when results are empty', async () => {
    userApi.searchUsers.mockResolvedValue([])
    render(<UserSearch />)

    await userEvent.type(screen.getByPlaceholderText(/search/i), 'notexist')
    fireEvent.click(screen.getByRole('button', { name: /search/i }))

    await waitFor(() => {
      expect(screen.getByText(/no users match/i)).toBeTruthy()
    })
  })

  it('shows an error banner when the API call fails', async () => {
    userApi.searchUsers.mockRejectedValue(new Error('Network Error'))
    render(<UserSearch />)

    fireEvent.click(screen.getByRole('button', { name: /search/i }))

    await waitFor(() => {
      expect(screen.getByRole('alert')).toBeTruthy()
      expect(screen.getByText(/failed to fetch/i)).toBeTruthy()
    })
  })

  it('clears results when Clear button is clicked', async () => {
    userApi.searchUsers.mockResolvedValue(MOCK_USERS)
    render(<UserSearch />)

    fireEvent.click(screen.getByRole('button', { name: /search/i }))
    await waitFor(() => screen.getByText('John Doe'))

    fireEvent.click(screen.getByRole('button', { name: /clear/i }))
    expect(screen.queryByText('John Doe')).toBeNull()
  })

  it('renders role and department tags for each user', async () => {
    userApi.searchUsers.mockResolvedValue(MOCK_USERS)
    render(<UserSearch />)

    fireEvent.click(screen.getByRole('button', { name: /search/i }))

    await waitFor(() => {
      expect(screen.getByText('Engineer')).toBeTruthy()
      expect(screen.getByText('Backend')).toBeTruthy()
    })
  })
})
