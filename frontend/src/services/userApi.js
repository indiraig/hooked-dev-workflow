import axios from 'axios'

const BASE_URL = '/api/users'

/**
 * Search users by name, email, or department.
 * @param {string} query - search term
 * @returns {Promise<Array>} list of matching users
 */
export async function searchUsers(query = '') {
  const response = await axios.get(`${BASE_URL}/search`, {
    params: { q: query },
  })
  return response.data
}

/**
 * Fetch every user.
 * @returns {Promise<Array>}
 */
export async function getAllUsers() {
  const response = await axios.get(BASE_URL)
  return response.data
}

/**
 * Fetch a single user by ID.
 * @param {number} id
 * @returns {Promise<Object>}
 */
export async function getUserById(id) {
  const response = await axios.get(`${BASE_URL}/${id}`)
  return response.data
}

/**
 * Create a new user.
 * @param {{name:string, email:string, role?:string, department?:string}} user
 * @returns {Promise<Object>} the created user
 */
export async function createUser(user) {
  const response = await axios.post(BASE_URL, user)
  return response.data
}

/**
 * Update an existing user (partial update supported).
 * @param {number} id
 * @param {Object} changes
 * @returns {Promise<Object>} the updated user
 */
export async function updateUser(id, changes) {
  const response = await axios.put(`${BASE_URL}/${id}`, changes)
  return response.data
}

/**
 * Delete a user by ID.
 * @param {number} id
 * @returns {Promise<void>}
 */
export async function deleteUser(id) {
  await axios.delete(`${BASE_URL}/${id}`)
}
