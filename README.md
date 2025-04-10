#  Clean Architecture Code Generator for Android (Kotlin)

This script automates the generation of a clean architecture structure in Android using Kotlin, Room, Hilt, and the Repository pattern. With a single command, it scaffolds all the necessary layers to work with a given entity, including:

- `Entity`
- `Repository`
- `Use Cases`
- `Room Dao`
- `Room Database`
- `RepositoryImpl`
- `Hilt DI Module`
- `BaseResult`

##  What does it generate?

Given an entity like `user`, it generates:

```
📁 domain/
 ├── model/UserEntity.kt
 ├── repository/UserRepository.kt
 ├── result/BaseResult.kt
 └── usecase/
     ├── InsertUserUseCase.kt
     ├── DeleteUserUseCase.kt
     ├── UpdateUserUseCase.kt
     └── FetchUserUseCase.kt

📁 data/
 ├── model/UserLocalModel.kt
 ├── db/UserDao.kt
 ├── db/DataModelDatabase.kt (centralized)
 └── repository/UserRepositoryImpl.kt

📁 di/
 └── AppModule.kt
```

##  Requirements

- Bash
- Kotlin
- Room
- Hilt (Dagger Hilt)
- Android project following `domain/`, `data/`, `di/` layered architecture

##  Installation

1. Copy the `generate-usecase.sh` file to the root of your Android project.
2. Make it executable:

```bash
chmod +x generate-usecase.sh
```

##  Usage

```bash
./generate-usecase.sh user com.example.yourapp
```

This will generate all the boilerplate files for the `User` entity, under the package `com.example.yourapp`.

> If no package is specified, it defaults to `com.example.test`.

---

##  Key Features

- ✔️ Generic `BaseResult.kt` for use case result handling.
- ✔️ Error handling using Kotlin `sealed class`.
- ✔️ Centralized Room DB file: `AppDatabase.db`
- ✔️ Repository implemented using DAO + basic mapping.
- ✔️ Auto configuration of Hilt dependency injection.
- ✔️ Does not overwrite existing files.

---

##  Example of a generated entity

```kotlin
// UserEntity.kt
data class UserEntity(
    val id: String,
    val name: String
)
```

---

##  Upcoming Features

- Auto-generation of ViewModel + UiState
- Mapping between LocalModel ↔ Entity
- `presentation/` layer scaffolding
- Support for multi-feature modular projects

---

##  Contributing

Contributions are welcome! Feel free to open an issue or pull request 

---
