<script setup>
import { ref, onMounted, computed } from 'vue'

const currentPath = ref('/')
const files = ref([])
const newFolderName = ref('')
const showCreateFolder = ref(false)
const uploadInput = ref(null)
const viewingFile = ref(null)
const textContent = ref('')

const sortedFiles = computed(() => {
  return [...files.value].sort((a, b) => {
    if (a.type === b.type) {
      return a.name.localeCompare(b.name)
    }
    return a.type === 'directory' ? -1 : 1
  })
})

const fetchFiles = async () => {
  try {
    const response = await fetch(`/api/list?path=${encodeURIComponent(currentPath.value)}`)
    const data = await response.json()
    if (data.files) {
      files.value = data.files
    } else {
      alert('Error fetching files: ' + (data.error || 'Unknown error'))
    }
  } catch (e) {
    console.error(e)
    alert('Network error')
  }
}

const navigate = (path) => {
  currentPath.value = path
  fetchFiles()
}

const goUp = () => {
  if (currentPath.value === '/') return
  const parts = currentPath.value.split('/').filter(p => p)
  parts.pop()
  const newPath = '/' + parts.join('/')
  navigate(newPath)
}

const createFolder = async () => {
  if (!newFolderName.value) return
  const path = currentPath.value === '/' ? `/${newFolderName.value}` : `${currentPath.value}/${newFolderName.value}`
  
  const formData = new URLSearchParams()
  formData.append('path', path)
  
  try {
    const response = await fetch('/api/create_folder', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: formData
    })
    const data = await response.json()
    if (data.success) {
      newFolderName.value = ''
      showCreateFolder.value = false
      fetchFiles()
    } else {
      alert('Error creating folder: ' + data.error)
    }
  } catch (e) {
    alert('Error creating folder')
  }
}

const deleteItem = async (item) => {
  if (!confirm(`Are you sure you want to delete ${item.name}?`)) return
  
  const formData = new URLSearchParams()
  formData.append('path', item.path)
  
  try {
    const response = await fetch('/api/delete', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: formData
    })
    const data = await response.json()
    if (data.success) {
      fetchFiles()
    } else {
      alert('Error deleting item: ' + data.error)
    }
  } catch (e) {
    alert('Error deleting item')
  }
}

const handleUpload = async (event) => {
  const file = event.target.files[0]
  if (!file) return
  
  const formData = new FormData()
  formData.append('file', file)
  formData.append('path', currentPath.value)
  
  try {
    const response = await fetch('/api/upload', {
      method: 'POST',
      body: formData
    })
    const data = await response.json()
    if (data.success) {
      fetchFiles()
    } else {
      alert('Error uploading file: ' + data.error)
    }
  } catch (e) {
    alert('Error uploading file')
  } finally {
    if (uploadInput.value) uploadInput.value.value = ''
  }
}

const getDownloadUrl = (item) => {
  return `/api/file?path=${encodeURIComponent(item.path)}`
}

const isImage = (name) => /\.(jpg|jpeg|png|gif|webp|bmp|ico)$/i.test(name)
const isPdf = (name) => /\.pdf$/i.test(name)
const isAudio = (name) => /\.(mp3|wav|aac|m4a|ogg)$/i.test(name)
const isVideo = (name) => /\.(mp4|mov|avi|webm|mkv)$/i.test(name)
const isText = (name) => /\.(txt|log|json|xml|md|swift|h|m|c|cpp|js|css|html|plist)$/i.test(name)

const canView = (name) => {
  return isImage(name) || isPdf(name) || isAudio(name) || isVideo(name) || isText(name)
}

const viewFile = async (item) => {
  viewingFile.value = item
  textContent.value = ''
  
  if (isText(item.name)) {
    try {
      const response = await fetch(getDownloadUrl(item))
      textContent.value = await response.text()
    } catch (e) {
      textContent.value = 'Error loading text content'
    }
  }
}

const closeViewer = () => {
  viewingFile.value = null
  textContent.value = ''
}

onMounted(() => {
  fetchFiles()
})
</script>

<template>
  <div class="container">
    <header>
      <h1>Sandbox Browser</h1>
      <div class="controls">
        <button @click="goUp" :disabled="currentPath === '/'">⬆️ Up</button>
        <button @click="showCreateFolder = !showCreateFolder" :disabled="currentPath === '/'">📁 New Folder</button>
        <label class="upload-btn" :class="{ disabled: currentPath === '/' }">
          📤 Upload
          <input type="file" ref="uploadInput" @change="handleUpload" style="display: none" :disabled="currentPath === '/'">
        </label>
      </div>
      <div class="path">Current Path: {{ currentPath }}</div>
      
      <div v-if="showCreateFolder" class="create-folder">
        <input v-model="newFolderName" placeholder="Folder Name" @keyup.enter="createFolder">
        <button @click="createFolder">Create</button>
      </div>
    </header>

    <main>
      <ul class="file-list">
        <li v-if="files.length === 0" class="empty">No files</li>
        <li v-for="item in sortedFiles" :key="item.name" class="file-item">
          <div class="file-info" @click="item.type === 'directory' ? navigate(item.path) : (canView(item.name) ? viewFile(item) : null)">
            <span class="icon">{{ item.type === 'directory' ? '📁' : (isImage(item.name) ? '🖼️' : '📄') }}</span>
            <span class="name">{{ item.name }}</span>
            <span class="size" v-if="item.type === 'file'">{{ (item.size / 1024).toFixed(1) }} KB</span>
          </div>
          <div class="actions">
            <a v-if="item.type === 'file'" :href="getDownloadUrl(item)" target="_blank" download>⬇️</a>
            <button v-if="item.type === 'file' && canView(item.name)" @click="viewFile(item)">👁️</button>
            <button @click="deleteItem(item)" class="delete-btn">🗑️</button>
          </div>
        </li>
      </ul>
    </main>

    <div v-if="viewingFile" class="viewer-overlay" @click.self="closeViewer">
      <div class="viewer-content">
        <div class="viewer-header">
          <h3>{{ viewingFile.name }}</h3>
          <button @click="closeViewer">Close</button>
        </div>
        <div class="viewer-body">
          <img v-if="isImage(viewingFile.name)" :src="getDownloadUrl(viewingFile)" alt="Preview">
          <iframe v-else-if="isPdf(viewingFile.name)" :src="getDownloadUrl(viewingFile)" width="100%" height="100%"></iframe>
          <audio v-else-if="isAudio(viewingFile.name)" :src="getDownloadUrl(viewingFile)" controls></audio>
          <video v-else-if="isVideo(viewingFile.name)" :src="getDownloadUrl(viewingFile)" controls></video>
          <pre v-else-if="isText(viewingFile.name)">{{ textContent }}</pre>
          <div v-else>Preview not available</div>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.container {
  max-width: 800px;
  margin: 0 auto;
  padding: 20px;
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
}

header {
  margin-bottom: 20px;
  border-bottom: 1px solid #eee;
  padding-bottom: 20px;
}

.controls {
  display: flex;
  gap: 10px;
  margin: 10px 0;
}

button, .upload-btn {
  padding: 8px 16px;
  background: #007AFF;
  color: white;
  border: none;
  border-radius: 6px;
  cursor: pointer;
  font-size: 14px;
}

button:disabled {
  background: #ccc;
  cursor: not-allowed;
}

.upload-btn.disabled {
  background: #ccc;
  cursor: not-allowed;
  pointer-events: none;
}

.delete-btn {
  background: #FF3B30;
  padding: 4px 8px;
}

.path {
  font-family: monospace;
  background: #f5f5f5;
  padding: 8px;
  border-radius: 4px;
  word-break: break-all;
}

.create-folder {
  margin-top: 10px;
  display: flex;
  gap: 10px;
}

.create-folder input {
  padding: 8px;
  border: 1px solid #ddd;
  border-radius: 4px;
  flex: 1;
}

.file-list {
  list-style: none;
  padding: 0;
}

.file-item {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 12px;
  border-bottom: 1px solid #eee;
}

.file-item:hover {
  background: #f9f9f9;
}

.file-info {
  display: flex;
  align-items: center;
  gap: 10px;
  flex: 1;
  cursor: pointer;
}

.name {
  font-weight: 500;
}

.size {
  color: #888;
  font-size: 12px;
}

.actions {
  display: flex;
  gap: 10px;
  align-items: center;
}

.actions a {
  text-decoration: none;
  font-size: 18px;
}

.viewer-overlay {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: rgba(0, 0, 0, 0.8);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
}

.viewer-content {
  background: white;
  width: 90%;
  height: 90%;
  border-radius: 8px;
  display: flex;
  flex-direction: column;
  overflow: hidden;
}

.viewer-header {
  padding: 10px 20px;
  border-bottom: 1px solid #eee;
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.viewer-body {
  flex: 1;
  overflow: auto;
  padding: 20px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: #f5f5f5;
}

.viewer-body img, .viewer-body video {
  max-width: 100%;
  max-height: 100%;
  object-fit: contain;
}

.viewer-body iframe {
  border: none;
}

.viewer-body pre {
  width: 100%;
  height: 100%;
  overflow: auto;
  background: white;
  padding: 10px;
  margin: 0;
  white-space: pre-wrap;
  text-align: left;
}
</style>
