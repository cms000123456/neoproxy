# Deploy Key Setup

This repository uses an SSH deploy key for authentication with GitHub.

## Public Key (Add to GitHub)

Add this public key to your GitHub repository:

**Repository**: `cms000123456/neoproxy`

### Steps:

1. Go to: https://github.com/cms000123456/neoproxy/settings/keys
2. Click **"Add deploy key"**
3. **Title**: `Neoproxy Deploy Key`
4. **Key**: Paste the public key below
5. **Allow write access**: ✅ Check this box (required for pushing)
6. Click **"Add key"**

---

**Public Key** (copy everything including `ssh-ed25519`):

```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDJhLXGHqPdjI0m8NyU4J2ggHlb5bPcNZROrl1i3EgtZ deploy@neoproxy
```

---

## Configure Git to Use Deploy Key

### Option 1: SSH Config (Recommended)

Edit `~/.ssh/config`:

```ssh-config
Host neoproxy-github
    HostName github.com
    User git
    IdentityFile ~/.ssh/neoproxy_deploy_key
    IdentitiesOnly yes
```

Then update the remote URL:

```bash
git remote set-url origin git@neoproxy-github:cms000123456/neoproxy.git
```

### Option 2: GIT_SSH_COMMAND Environment Variable

```bash
export GIT_SSH_COMMAND="ssh -i /path/to/neoproxy/.github/deploy_key -o IdentitiesOnly=yes"
git push origin main
```

### Option 3: Git Config

```bash
git config core.sshCommand "ssh -i /path/to/neoproxy/.github/deploy_key -o IdentitiesOnly=yes"
```

## Testing the Connection

```bash
ssh -i .github/deploy_key -T git@github.com
```

Expected output:
```
Hi cms000123456/neoproxy! You've successfully authenticated, but GitHub does not provide shell access.
```

## Initial Push

```bash
# Add the remote (if not already done)
git remote add origin git@github.com:cms000123456/neoproxy.git

# Or update existing remote
git remote set-url origin git@github.com:cms000123456/neoproxy.git

# Push to GitHub
git push -u origin main
```

## Security Notes

- 🔒 **Never commit the private key** (`.github/deploy_key`) to Git!
- 🔒 The private key file should have permissions `600`
- 🔒 Store the private key securely (password manager, etc.)
- 🔒 If the key is compromised, revoke it in GitHub immediately and generate a new one

## Troubleshooting

### Permission denied

```bash
# Check key permissions
chmod 600 .github/deploy_key

# Test verbose
ssh -v -i .github/deploy_key -T git@github.com
```

### Wrong key being used

Make sure `IdentitiesOnly yes` is set to prevent SSH from trying other keys first.

### Repository not found

Ensure the deploy key has **write access** enabled in GitHub settings.
