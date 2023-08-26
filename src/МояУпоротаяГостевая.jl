#
# Тестовый проект "Упоротая гостевая"
# Написан ради статьи в блоге https://teletype.in/@alex0x08
# Для большего фана, все что можно было локализовано.
#
module МояУпоротаяГостевая
# используемые библиотеки
using Oxygen,SwaggerMarkdown,HTTP,StructTypes,MySQL,Dates,Preferences,Pkg
using Base: UUID
# эта военная хитрость необходима чтобы обойти ограничение TOML на ANSII символы в ключах.
# Фейковый UUID пакета, определяющийся через [extras] секцию
Preferences.main_uuid[] = UUID("16e4e860-d6b8-5056-a518-93e88b6392ae")
# DTO с настройками подключения к базе
struct НастройкаПодключения
    хост::String
    база::String
    юзер::String
    пароль::String
    function НастройкаПодключения()
        new(@load_preference("dbserver"),
            @load_preference("dbdb"),
            @load_preference("dbuser"),
            @load_preference("dbpassword"))     
    end    
end    
#
# Типа DTO/Entity для записи в гостевой
struct Пост
    # ID записи, автогенерируется
    id::Int32 
    # заголовок
    title::String
    # автор
    author::String
    # текст сообщения
    message::String
    # дата создания
    createdDt::Dates.DateTime
    # свой конструктор, для обработки пустого ID, когда это DTO используется для добавления нового поста
    function Пост(id, title, author,message,createdDt)
        new(id != nothing ? id : 0, title, author, message,createdDt != nothing ? createdDt : Dates.DateTime(0))
    end    
end

# Регистрация нашего DTO для автоматической (де)сериализации через библиотеку JSON3
StructTypes.StructType(::Type{Пост}) = StructTypes.Struct()
# подключение к базе
подключение = nothing

# инициализация модуля (как в петоне)
function __init__()
	setup()
end
# инициализация Упоротой Гостевой
function setup() 
    @info "инициализация.."
    @debug "упоротая отладка включена, поздравляю!"
    # Да, тут тоже есть Swagger
    @swagger """
        /api/records:
            get:
                description: Отдает все посты в гостевой
                responses:
                    '200':
                        description: Типа все ОК.
    """
    @get "/api/records" function(req::HTTP.Request)
        @debug "вызов API получения всех постов"
        # выходной массив с постами
        посты = Пост[]
        # получить выборку
        курсор = DBInterface.execute(МояУпоротаяГостевая.подключение, 
                "select p.* from posts p order by p.created_dt desc limit 500") 
        # формируем запись и пихаем в массив
        for запись in курсор
            push!(посты, Пост(запись[1], запись[2], запись[3],запись[4],запись[5]))
        end    
        # отдаем массив DTO, который будет автоматически сериализован в JSON
        return посты
    end
    @swagger """
        /api/delete:
            get:
                description: Удаляет запись гостевой
                responses:
                    '200':
                        description: Типа все ОК.
    """
    @post "/api/delete" function(req::HTTP.Request)
        @debug "вызов API удаления поста"
        params=queryparams(req)
        # проверка "notin" - ключ id не в Dict
        if ("id" ∉ keys(params))
            return HTTP.Response(400, "Параметр ID обязателен")        
        end    
        recordId = params["id"]
        if (length(recordId)<1 || length(recordId)>500)
            return HTTP.Response(400, "Параметр ID какой-то кривой")      
        end        
        DBInterface.execute(МояУпоротаяГостевая.подключение, "delete from posts where id = $(recordId)") 
        HTTP.Response(200, "Запись удалена")    
    end
    @swagger """
        /api/add:
            get:
                description: Добавляет или обновляет запись гостевой
                responses:
                    '200':
                        description: Типа все ОК.
    """
    @post "/api/add" function(req::HTTP.Request)
        @debug "вызов API добаления/обновления поста"
        пост = nothing
        # десериализуем из строки JSON в теле запроса в struct
        try
            пост = json(req, Пост)
        catch error 
            @error "Ошибка разбора JSON: " exception=(error, catch_backtrace())
            return HTTP.Response(500, "Упоротый сервер совершил ошибку")
        end 
        if (length(пост.title)<3 || length(пост.author)<3 || length(пост.message)<3)
            return HTTP.Response(400, "Недостаточно данных для создания поста")
        end     
        # если не был указан id то создаем запись
        if (пост.id>0)
            курсор = DBInterface.execute(МояУпоротаяГостевая.подключение, 
                "UPDATE posts SET title='$(пост.title)', author='$(пост.author)', 
                    message='$(пост.message)', createdDt = now() WHERE id=$(пост.id)")
        # если указан - обновляем
        else
            курсор = DBInterface.execute(МояУпоротаяГостевая.подключение, 
                "INSERT INTO posts (title, author, message) VALUES ('$(пост.title)','$(пост.author)','$(пост.message)')")
        end
        # ID созданной/обновленной записи
        идЗаписи = DBInterface.lastrowid(курсор)
        # вытаскиваем обновленную запись
        курсор2 = DBInterface.execute(МояУпоротаяГостевая.подключение, 
                "select p.* from posts p where p.id = $(идЗаписи)") 
        # получаем сами данные из курсора
        запись = first(курсор2)
        # возвращаем DTO, которое будет автоматически превращено в JSON
        return Пост(запись[1], запись[2], запись[3],запись[4],запись[5])
    end

    # отдача страницы по-умолчанию
    get("/") do
        return file("content/gb.html")
    end
    # иконка
    get("/favicon.ico") do
        return file("content/favicon.ico")
    end

    # метаданные для сваггера
    info = Dict("title" => "API для упоротой гостевой", "version" => "1.0.0")
    openApi = OpenAPI("3.0", info)
    swagger_document = build(openApi)
    # генерация документации
    mergeschema(swagger_document)

end
function isREPL()
    abspath(PROGRAM_FILE) != @__FILE__
end     
# отдельная функция для запуска сервера, чтобы вызывать через REPL
function runserver()
    @info "запуск упоротой гостевой"
    # отдача статики из папки "content", будет отдаваться по пути "/static" 
    staticfiles("content", "static")
    # загрузка настроек подключения
    настройка = НастройкаПодключения()
    # подключение к СУБД
    МояУпоротаяГостевая.подключение = DBInterface.connect(MySQL.Connection,
                    настройка.хост, 
                    настройка.юзер, 
                    настройка.пароль, db=настройка.база)
    @info "Подключение к СУБД установлено"
    # запуск HTTP сервера
    if isREPL()
        serve()
    else
        serveparallel()
    end
end
# если запуск не через REPL - считаем себя программой и запускаемся
if !isREPL()
    # отдельно вызов настройки
    setup()
    # запуск 
    runserver()
end

end # конец модуля
