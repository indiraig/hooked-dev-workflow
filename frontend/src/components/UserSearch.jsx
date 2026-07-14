import { useState, useCallback, useEffect } from 'react'
import {
  searchUsers,
  getAllUsers,
  createUser,
  updateUser,
  deleteUser,
} from '../services/userApi'
import './UserSearch.css'

const EMPTY_FORM = { name: '', email: '', role: '', department: '' }

const FEATURES = [
  {
    tag: 'Search',
    title: 'Search users',
    desc: 'Find people by name, email, or department in real time.',
  },
  {
    tag: 'Create',
    title: 'Add a user',
    desc: 'Register a new user with name, email, role, and department.',
  },
  {
    tag: 'Update',
    title: 'Edit details',
    desc: 'Update any user\u2019s role, department, or contact info.',
  },
  {
    tag: 'Delete',
    title: 'Remove a user',
    desc: 'Delete a user you no longer need with one click.',
  },
]

export default function UserSearch() {
  const [query, setQuery] = useState('')
  const [users, setUsers] = useState([])
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState(null)
  const [notice, setNotice] = useState(null)
  const [searched, setSearched] = useState(false)

  // Create / edit form state
  const [showForm, setShowForm] = useState(false)
  const [editingId, setEditingId] = useState(null)
  const [form, setForm] = useState(EMPTY_FORM)
  const [formError, setFormError] = useState(null)
  const [saving, setSaving] = useState(false)

  // Load all users on first render so the list is populated.
  const loadAll = useCallback(async () => {
    try {
      const data = await getAllUsers()
      setUsers(Array.isArray(data) ? data : [])
    } catch {
      setUsers([])
    }
  }, [])

  useEffect(() => {
    loadAll()
  }, [loadAll])

  const handleSearch = useCallback(
    async (e) => {
      e.preventDefault()
      setLoading(true)
      setError(null)
      setNotice(null)
      setSearched(true)
      try {
        const results = await searchUsers(query)
        setUsers(results)
      } catch {
        setError('Failed to fetch users. Make sure the backend is running.')
        setUsers([])
      } finally {
        setLoading(false)
      }
    },
    [query],
  )

  const handleClear = () => {
    setQuery('')
    setUsers([])
    setSearched(false)
    setError(null)
    setNotice(null)
  }

  // ---- Create / Edit ----
  const openCreate = () => {
    setEditingId(null)
    setForm(EMPTY_FORM)
    setFormError(null)
    setShowForm(true)
  }

  const openEdit = (user) => {
    setEditingId(user.id)
    setForm({
      name: user.name || '',
      email: user.email || '',
      role: user.role || '',
      department: user.department || '',
    })
    setFormError(null)
    setShowForm(true)
  }

  const closeForm = () => {
    setShowForm(false)
    setFormError(null)
  }

  const handleFormChange = (field) => (e) =>
    setForm((prev) => ({ ...prev, [field]: e.target.value }))

  const handleSubmitForm = async (e) => {
    e.preventDefault()
    if (!form.name.trim() || !form.email.trim()) {
      setFormError('Name and email are required.')
      return
    }
    setSaving(true)
    setFormError(null)
    try {
      if (editingId == null) {
        await createUser(form)
        setNotice(`User "${form.name}" created.`)
      } else {
        await updateUser(editingId, form)
        setNotice(`User "${form.name}" updated.`)
      }
      setShowForm(false)
      setSearched(false)
      setQuery('')
      await loadAll()
    } catch (err) {
      const status = err?.response?.status
      if (status === 409) setFormError('A user with that email already exists.')
      else if (status === 422) setFormError('Please enter a valid email address.')
      else setFormError('Something went wrong. Is the backend running?')
    } finally {
      setSaving(false)
    }
  }

  const handleDelete = async (user) => {
    if (!window.confirm(`Delete ${user.name}? This cannot be undone.`)) return
    setError(null)
    setNotice(null)
    try {
      await deleteUser(user.id)
      setNotice(`User "${user.name}" deleted.`)
      setUsers((prev) => prev.filter((u) => u.id !== user.id))
    } catch {
      setError('Failed to delete user. Please try again.')
    }
  }

  return (
    <div className="user-search">
      <header className="search-header">
        <h1>User Directory</h1>
        <p className="subtitle">
          Search, create, update, and delete users &middot; AI-Assisted Developer Workflow Demo
        </p>
      </header>

      {/* ---- What you can do ---- */}
      <section className="features" aria-label="Features">
        {FEATURES.map((f) => (
          <div key={f.tag} className="feature-card">
            <span className={`feature-tag feature-${f.tag.toLowerCase()}`}>{f.tag}</span>
            <h3 className="feature-title">{f.title}</h3>
            <p className="feature-desc">{f.desc}</p>
          </div>
        ))}
      </section>

      {/* ---- Toolbar: search + add ---- */}
      <form className="search-form" onSubmit={handleSearch} role="search">
        <div className="search-input-group">
          <input
            type="text"
            className="search-input"
            placeholder="Search by name, email, or department..."
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            aria-label="Search users"
          />
          <button type="submit" className="btn btn-primary" disabled={loading}>
            {loading ? 'Searching...' : 'Search'}
          </button>
          {searched && (
            <button type="button" className="btn btn-secondary" onClick={handleClear}>
              Clear
            </button>
          )}
          <button type="button" className="btn btn-success" onClick={openCreate}>
            + Add User
          </button>
        </div>
      </form>

      {notice && (
        <div className="notice-banner" role="status">
          {notice}
        </div>
      )}

      {error && (
        <div className="error-banner" role="alert">
          {error}
        </div>
      )}

      {/* ---- Results ---- */}
      {!loading && !error && (searched || users.length > 0) && (
        <div className="results-section">
          <p className="results-count">
            {users.length} {users.length === 1 ? 'result' : 'results'} found
            {searched && query && <span> for &quot;{query}&quot;</span>}
          </p>

          {searched && users.length === 0 ? (
            <p className="no-results">No users match your search.</p>
          ) : (
            <ul className="user-list" role="list">
              {users.map((user) => (
                <li key={user.id} className="user-card" role="listitem">
                  <div className="user-avatar">
                    {user.name.charAt(0).toUpperCase()}
                  </div>
                  <div className="user-info">
                    <h3 className="user-name">{user.name}</h3>
                    <p className="user-email">{user.email}</p>
                    <div className="user-tags">
                      {user.role && <span className="tag tag-role">{user.role}</span>}
                      {user.department && <span className="tag tag-dept">{user.department}</span>}
                    </div>
                  </div>
                  <div className="user-actions">
                    <button
                      type="button"
                      className="btn btn-ghost"
                      onClick={() => openEdit(user)}
                      aria-label={`Edit ${user.name}`}
                    >
                      Edit
                    </button>
                    <button
                      type="button"
                      className="btn btn-danger"
                      onClick={() => handleDelete(user)}
                      aria-label={`Delete ${user.name}`}
                    >
                      Delete
                    </button>
                  </div>
                </li>
              ))}
            </ul>
          )}
        </div>
      )}

      {/* ---- Create / Edit modal ---- */}
      {showForm && (
        <div className="modal-overlay" role="dialog" aria-modal="true" onClick={closeForm}>
          <div className="modal" onClick={(e) => e.stopPropagation()}>
            <h2 className="modal-title">{editingId == null ? 'Add User' : 'Edit User'}</h2>
            <form onSubmit={handleSubmitForm} className="user-form">
              <label className="field">
                <span>Name *</span>
                <input
                  className="search-input"
                  value={form.name}
                  onChange={handleFormChange('name')}
                  placeholder="Full name"
                />
              </label>
              <label className="field">
                <span>Email *</span>
                <input
                  className="search-input"
                  type="email"
                  value={form.email}
                  onChange={handleFormChange('email')}
                  placeholder="name@example.com"
                />
              </label>
              <label className="field">
                <span>Role</span>
                <input
                  className="search-input"
                  value={form.role}
                  onChange={handleFormChange('role')}
                  placeholder="Engineer, Designer, Manager..."
                />
              </label>
              <label className="field">
                <span>Department</span>
                <input
                  className="search-input"
                  value={form.department}
                  onChange={handleFormChange('department')}
                  placeholder="Backend, Frontend, Product..."
                />
              </label>

              {formError && <div className="error-banner">{formError}</div>}

              <div className="modal-actions">
                <button type="button" className="btn btn-secondary" onClick={closeForm}>
                  Cancel
                </button>
                <button type="submit" className="btn btn-primary" disabled={saving}>
                  {saving ? 'Saving...' : editingId == null ? 'Create' : 'Save changes'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  )
}
