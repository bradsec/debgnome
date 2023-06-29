
# debgnome.sh
## A bash shell script for automating and customising the appearance of the GNOME desktop on Debian based distros.

![debgnome](/screenshot.png)

## USAGE 
#### Option 1. Run with default selection of extensions
Use the wget or curl command lines shown below for quick setup.

```terminal
bash -c "$(wget -qO- https://raw.githubusercontent.com/bradsec/debgnome/main/debgnome.sh)"
```

```terminal
bash -c "$(curl -fsSL https://raw.githubusercontent.com/bradsec/debgnome/main/debgnome.sh)"
```

#### Option 2. Clone, modify or customise extensions and run locally. 
(Optional) You can edit and modify script to suit using this method.

Edit the `main()` function and specify the GNOME extensions you want installed.


```terminal
git clone https://github.com/debgnome.git
```

```terminal
# Running after cloning repo 
cd debgnome
bash debgnome.sh
```

```terminal
# Alternatively make executable
cd debgnome
chmod +x debgnome.sh
./debgnome.sh
```