#!/bin/bash

ENTITY=$1
PACKAGE_NAME=$2
PACKAGE_DEFAULT="com.example.test"
if [ -z "$ENTITY" ]; then
  echo "Error: You must provide the entity name. Example: ./generate-usecase.sh user ${PACKAGE_DEFAULT}"
  exit 1
fi

if [ -z "$PACKAGE_NAME" ]; then
  PACKAGE_NAME="${PACKAGE_DEFAULT}"
fi

# Convert names
ENTITY_BASE=$(echo "$ENTITY" | awk '{print tolower($0)}')
ENTITY_CAMEL="$(tr '[:lower:]' '[:upper:]' <<< ${ENTITY_BASE:0:1})${ENTITY_BASE:1}"
ENTITY_CLASS="${ENTITY_CAMEL}Entity"
ENTITY_VAR="$(tr '[:upper:]' '[:lower:]' <<< ${ENTITY_CAMEL:0:1})${ENTITY_CAMEL:1}Entity"
CLASS_RESULT_NAME="BaseResult"

# Reusable DB name
DB_NAME="AppDatabase.db"

# Create required folders
mkdir -p domain/model
mkdir -p domain/repository
mkdir -p domain/usecase
mkdir -p domain/result
mkdir -p data/model
mkdir -p data/db
mkdir -p data/repository
mkdir -p di

# Create Entity model
MODEL_FILE="domain/model/${ENTITY_CLASS}.kt"
if [ ! -f "$MODEL_FILE" ]; then
cat <<EOF > "$MODEL_FILE"
package ${PACKAGE_NAME}.domain.model

data class ${ENTITY_CLASS}(
    val id: String,
    val name: String
)
EOF
  echo "Model ${ENTITY_CLASS}.kt created."
fi

# Create generic Result class if not exists
RESULT_FILE="domain/result/${CLASS_RESULT_NAME}.kt"
if [ ! -f "$RESULT_FILE" ]; then
cat <<EOF > "$RESULT_FILE"
package ${PACKAGE_NAME}.domain.result

sealed class ${CLASS_RESULT_NAME}<out T> {
    data class Success<out T>(val data: T): ${CLASS_RESULT_NAME}<T>()
    data class Error(val exception: Throwable): ${CLASS_RESULT_NAME}<Nothing>()
    data object ErrorEmpty: ${CLASS_RESULT_NAME}<Nothing>()
}
EOF
  echo "Sealed class ${CLASS_RESULT_NAME}.kt created."
fi

# Create repository interface
REPO_FILE="domain/repository/${ENTITY_CAMEL}Repository.kt"
if [ ! -f "$REPO_FILE" ]; then
cat <<EOF > "$REPO_FILE"
package ${PACKAGE_NAME}.domain.repository

import ${PACKAGE_NAME}.domain.model.${ENTITY_CLASS}
import ${PACKAGE_NAME}.domain.result.${CLASS_RESULT_NAME}

interface ${ENTITY_CAMEL}Repository {
    suspend fun insert${ENTITY_CAMEL}(${ENTITY_BASE}: ${ENTITY_CLASS}): ${CLASS_RESULT_NAME}<${ENTITY_CLASS}>
    suspend fun delete${ENTITY_CAMEL}(${ENTITY_BASE}: ${ENTITY_CLASS}): ${CLASS_RESULT_NAME}<${ENTITY_CLASS}>
    suspend fun update${ENTITY_CAMEL}(${ENTITY_BASE}: ${ENTITY_CLASS}): ${CLASS_RESULT_NAME}<${ENTITY_CLASS}>
    suspend fun fetch${ENTITY_CAMEL}(): ${CLASS_RESULT_NAME}<List<${ENTITY_CLASS}>>
}
EOF
  echo "Repository ${ENTITY_CAMEL}Repository.kt created."
fi

# Create use cases
for action in Insert Delete Update Fetch
do
  FILENAME="domain/usecase/${action}${ENTITY_CAMEL}UseCase.kt"
  if [ ! -f "$FILENAME" ]; then
    METHOD_NAME="$(echo "${action}" | tr '[:upper:]' '[:lower:]')${ENTITY_CAMEL}"
    RETURN_TYPE="${CLASS_RESULT_NAME}<${ENTITY_CLASS}>"

    if [ "$action" = "Fetch" ]; then
      BODY="repository.fetch${ENTITY_CAMEL}()"
      PARAMS=""
      RETURN_TYPE="${CLASS_RESULT_NAME}<List<${ENTITY_CLASS}>>"
    else
      BODY="repository.${METHOD_NAME}(${ENTITY_BASE} = ${ENTITY_BASE})"
      PARAMS="${ENTITY_BASE}: ${ENTITY_CLASS}"
    fi

cat <<EOF > "$FILENAME"
package ${PACKAGE_NAME}.domain.usecase

import ${PACKAGE_NAME}.domain.model.${ENTITY_CLASS}
import ${PACKAGE_NAME}.domain.repository.${ENTITY_CAMEL}Repository
import ${PACKAGE_NAME}.domain.result.${CLASS_RESULT_NAME}

class ${action}${ENTITY_CAMEL}UseCase(
    private val repository: ${ENTITY_CAMEL}Repository
) {
    suspend fun execute(${PARAMS}): ${RETURN_TYPE} {
        return $BODY
    }
}
EOF
    echo "${action}${ENTITY_CAMEL}UseCase.kt generated."
  fi
done

# Create model local Room
ABRV_LOCAL_MODEL=""
LOCAL_MODEL_FILE="data/model/${ENTITY_CAMEL}${ABRV_LOCAL_MODEL}.kt"
if [ ! -f "$LOCAL_MODEL_FILE" ]; then
cat <<EOF > "$LOCAL_MODEL_FILE"
package ${PACKAGE_NAME}.data.model

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "${ENTITY_BASE}s")
data class ${ENTITY_CAMEL}${ABRV_LOCAL_MODEL}(
    @PrimaryKey val id: String,
    val name: String,
    val isDeleted: Boolean = false
)
EOF
  echo "Model local ${ENTITY_CAMEL}${ABRV_LOCAL_MODEL}.kt created."
fi

# Create DAO
DAO_FILE="data/db/${ENTITY_CAMEL}Dao.kt"
if [ ! -f "$DAO_FILE" ]; then
cat <<EOF > "$DAO_FILE"
package ${PACKAGE_NAME}.data.db

import androidx.room.*
import ${PACKAGE_NAME}.data.model.${ENTITY_CAMEL}${ABRV_LOCAL_MODEL}

@Dao
interface ${ENTITY_CAMEL}Dao {
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(${ENTITY_BASE}: ${ENTITY_CAMEL}${ABRV_LOCAL_MODEL})

    @Update
    suspend fun update(${ENTITY_BASE}: ${ENTITY_CAMEL}${ABRV_LOCAL_MODEL})

    @Query("UPDATE ${ENTITY_BASE}s SET isDeleted = 1 WHERE id = :id")
    suspend fun softDelete(id: String)

    @Query("SELECT * FROM ${ENTITY_BASE}s WHERE isDeleted = 0")
    suspend fun getAll(): List<${ENTITY_CAMEL}${ABRV_LOCAL_MODEL}>
}
EOF
  echo "DAO ${ENTITY_CAMEL}Dao.kt created."
fi

# Create RepositoryImpl
IMPL_FILE="data/repository/${ENTITY_CAMEL}RepositoryImpl.kt"
if [ ! -f "$IMPL_FILE" ]; then
cat <<EOF > "$IMPL_FILE"
package ${PACKAGE_NAME}.data.repository

import ${PACKAGE_NAME}.data.db.${ENTITY_CAMEL}Dao
import ${PACKAGE_NAME}.data.model.${ENTITY_CAMEL}${ABRV_LOCAL_MODEL}
import ${PACKAGE_NAME}.domain.model.${ENTITY_CLASS}
import ${PACKAGE_NAME}.domain.repository.${ENTITY_CAMEL}Repository
import ${PACKAGE_NAME}.domain.result.${CLASS_RESULT_NAME}
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

class ${ENTITY_CAMEL}RepositoryImpl(
    private val dao: ${ENTITY_CAMEL}Dao
) : ${ENTITY_CAMEL}Repository {

    override suspend fun insert${ENTITY_CAMEL}(${ENTITY_BASE}: ${ENTITY_CLASS}): ${CLASS_RESULT_NAME}<${ENTITY_CLASS}> = withContext(Dispatchers.IO) {
        return@withContext try {
            dao.insert(${ENTITY_CAMEL}${ABRV_LOCAL_MODEL}(id = ${ENTITY_BASE}.id, name = ${ENTITY_BASE}.name))
            ${CLASS_RESULT_NAME}.Success(${ENTITY_BASE})
        } catch (e: Exception) {
            ${CLASS_RESULT_NAME}.Error(e)
        }
    }

    override suspend fun update${ENTITY_CAMEL}(${ENTITY_BASE}: ${ENTITY_CLASS}): ${CLASS_RESULT_NAME}<${ENTITY_CLASS}> = withContext(Dispatchers.IO) {
        return@withContext try {
            dao.update(${ENTITY_CAMEL}${ABRV_LOCAL_MODEL}(id = ${ENTITY_BASE}.id, name = ${ENTITY_BASE}.name))
            ${CLASS_RESULT_NAME}.Success(${ENTITY_BASE})
        } catch (e: Exception) {
            ${CLASS_RESULT_NAME}.Error(e)
        }
    }

    override suspend fun delete${ENTITY_CAMEL}(${ENTITY_BASE}: ${ENTITY_CLASS}): ${CLASS_RESULT_NAME}<${ENTITY_CLASS}> = withContext(Dispatchers.IO) {
        return@withContext try {
            dao.softDelete(${ENTITY_BASE}.id)
            ${CLASS_RESULT_NAME}.Success(${ENTITY_BASE})
        } catch (e: Exception) {
            ${CLASS_RESULT_NAME}.Error(e)
        }
    }

    override suspend fun fetch${ENTITY_CAMEL}(): ${CLASS_RESULT_NAME}<List<${ENTITY_CLASS}>> = withContext(Dispatchers.IO) {
        return@withContext try {
            val result = dao.getAll().map {
                ${ENTITY_CLASS}(id = it.id, name = it.name)
            }
            ${CLASS_RESULT_NAME}.Success(result)
        } catch (e: Exception) {
            ${CLASS_RESULT_NAME}.Error(e)
        }
    }
}
EOF
  echo "Implementation ${ENTITY_CAMEL}RepositoryImpl.kt created."
fi

# Create or update DataModelDatabase.kt
DATABASE_FILE="data/db/DataModelDatabase.kt"
ENTITY_LINE="${ENTITY_CAMEL}${ABRV_LOCAL_MODEL}::class"
DAO_LINE="abstract fun ${ENTITY_BASE}Dao(): ${ENTITY_CAMEL}Dao"

if [ ! -f "$DATABASE_FILE" ]; then
cat <<EOF > "$DATABASE_FILE"
package ${PACKAGE_NAME}.data.db

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase
import ${PACKAGE_NAME}.data.model.${ENTITY_CAMEL}${ABRV_LOCAL_MODEL}

@Database(
    entities = [${ENTITY_LINE}],
    version = 1,
    exportSchema = false
)
abstract class DataModelDatabase : RoomDatabase() {
    $DAO_LINE

    companion object {
        @Volatile private var instance: DataModelDatabase? = null
        private const val DB_NAME = "$DB_NAME"

        fun getDatabase(context: Context): DataModelDatabase =
            instance ?: synchronized(this) {
                instance ?: buildDatabase(context).also { instance = it }
            }

        private fun buildDatabase(appContext: Context) =
            Room.databaseBuilder(appContext, DataModelDatabase::class.java, DB_NAME)
                .fallbackToDestructiveMigration()
                .build()
    }
}
EOF
  echo "Database Room created $ENTITY_LINE."
fi

# Create or update AppModule.kt
DI_FILE="di/AppModule.kt"
if [ ! -f "$DI_FILE" ]; then
cat <<EOF > "$DI_FILE"
package ${PACKAGE_NAME}.di

import android.content.Context
import ${PACKAGE_NAME}.data.db.DataModelDatabase
import ${PACKAGE_NAME}.data.db.${ENTITY_CAMEL}Dao
import ${PACKAGE_NAME}.data.repository.${ENTITY_CAMEL}RepositoryImpl
import ${PACKAGE_NAME}.domain.repository.${ENTITY_CAMEL}Repository
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

@InstallIn(SingletonComponent::class)
@Module
object AppModule {

    //db
    @Singleton
    @Provides
    fun provideDataModelDatabase(@ApplicationContext appContext: Context) =
        DataModelDatabase.getDatabase(appContext)

}
EOF
  echo "AppModule.kt created."
fi